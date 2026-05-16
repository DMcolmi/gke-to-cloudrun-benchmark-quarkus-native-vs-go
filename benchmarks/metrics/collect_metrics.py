#!/usr/bin/env python3
"""
collect_metrics.py — Query Cloud Monitoring for a single Cloud Run service
and save the time series as JSON for later comparison.

Usage:
    python collect_metrics.py \
        --project PROJECT_ID \
        --service device-api-go \
        --start 2026-05-12T10:00:00Z \
        --end   2026-05-12T10:10:00Z \
        [--region europe-west8] \
        [--out-dir ./results]

Authentication:
    Uses Application Default Credentials.
    Run: gcloud auth application-default login
"""

import argparse
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

from google.cloud import monitoring_v3


# ---------------------------------------------------------------------------
# Metrics to collect
# ---------------------------------------------------------------------------
# aligner:      Cloud Monitoring per-series aligner name (must match Aligner enum)
# reduce:       Whether to apply REDUCE_SUM across revisions/labels → single series
# scale:        Multiply raw value before storing (e.g. 100 to convert 0-1 → %)
# unit:         Display unit for the JSON / charts
# extra_filter: Optional extra AND clause appended to the filter string
# ---------------------------------------------------------------------------
METRICS: dict = {
    "cpu_utilization": {
        "type": "run.googleapis.com/container/cpu/utilizations",
        "aligner": "ALIGN_DELTA",   # DELTA/DISTRIBUTION → ALIGN_DELTA; mean extracted from distribution_value.mean
        "reduce": True,
        "scale": 100.0,
        "unit": "% CPU",
        "extra_filter": "",
    },
    "memory_utilization": {
        "type": "run.googleapis.com/container/memory/utilizations",
        "aligner": "ALIGN_DELTA",   # DELTA/DISTRIBUTION → ALIGN_DELTA
        "reduce": True,
        "scale": 100.0,
        "unit": "% Memory",
        "extra_filter": "",
    },
    "instance_count": {
        "type": "run.googleapis.com/container/instance_count",
        "aligner": "ALIGN_MEAN",
        "reduce": True,
        "scale": 1.0,
        "unit": "instances",
        # Only count actively-serving instances (not CPU-throttled idle ones)
        "extra_filter": 'metric.labels.state="active"',
    },
    "request_count": {
        "type": "run.googleapis.com/request_count",
        "aligner": "ALIGN_RATE",   # DELTA → req/s
        "reduce": True,
        "scale": 1.0,
        "unit": "req/s",
        "extra_filter": "",
    },
    "request_latencies_mean": {
        "type": "run.googleapis.com/request_latencies",
        "aligner": "ALIGN_DELTA",   # DELTA/DISTRIBUTION → ALIGN_DELTA; mean extracted from distribution_value.mean
        "reduce": True,
        "scale": 1.0,
        "unit": "ms",
        "extra_filter": "",
    },
    "billable_instance_time": {
        "type": "run.googleapis.com/container/billable_instance_time",
        "aligner": "ALIGN_SUM",    # DELTA DOUBLE → billable seconds per window
        "reduce": True,
        "scale": 1.0,
        "unit": "s",
        "extra_filter": "",
    },
}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def parse_iso(s: str) -> datetime:
    s = s.strip()
    if s.endswith("Z"):
        s = s[:-1] + "+00:00"
    return datetime.fromisoformat(s)


def extract_value(typed_value) -> "float | None":
    """Extract a float from a proto-plus TypedValue (any value type)."""
    pb = type(typed_value).pb(typed_value)
    vt = pb.WhichOneof("value")
    if vt == "double_value":
        return pb.double_value
    if vt == "int64_value":
        return float(pb.int64_value)
    if vt == "distribution_value":
        dv = pb.distribution_value
        return float(dv.mean) if dv.count > 0 else 0.0
    return None


def ts_to_iso(ts_field) -> str:
    """Convert a proto-plus Timestamp or datetime field to ISO 8601 UTC string."""
    if isinstance(ts_field, datetime):
        return ts_field.astimezone(timezone.utc).isoformat()
    # Raw protobuf Timestamp fallback
    return datetime.fromtimestamp(ts_field.seconds, tz=timezone.utc).isoformat()


# ---------------------------------------------------------------------------
# Core collection
# ---------------------------------------------------------------------------

def collect_metric(
    client: monitoring_v3.MetricServiceClient,
    project_id: str,
    service: str,
    region: str,
    key: str,
    cfg: dict,
    start_dt: datetime,
    end_dt: datetime,
) -> list[dict]:
    """Query one metric and return a sorted list of {timestamp, value} dicts."""
    aligner = monitoring_v3.Aggregation.Aligner[cfg["aligner"]]

    filter_parts = [
        f'metric.type="{cfg["type"]}"',
        'resource.type="cloud_run_revision"',
        f'resource.labels.service_name="{service}"',
        f'resource.labels.location="{region}"',
    ]
    if cfg.get("extra_filter"):
        filter_parts.append(cfg["extra_filter"])
    filter_str = " AND ".join(filter_parts)

    agg = monitoring_v3.Aggregation(
        alignment_period={"seconds": 60},
        per_series_aligner=aligner,
    )
    if cfg.get("reduce", False):
        agg.cross_series_reducer = monitoring_v3.Aggregation.Reducer.REDUCE_SUM
        agg.group_by_fields = ["resource.labels.service_name"]

    request = monitoring_v3.ListTimeSeriesRequest(
        name=f"projects/{project_id}",
        filter=filter_str,
        interval=monitoring_v3.TimeInterval(
            start_time=start_dt,
            end_time=end_dt,
        ),
        view=monitoring_v3.ListTimeSeriesRequest.TimeSeriesView.FULL,
        aggregation=agg,
    )

    points: list[dict] = []
    try:
        for ts in client.list_time_series(request=request):
            for point in ts.points:
                t = ts_to_iso(point.interval.end_time)
                v = extract_value(point.value)
                if v is not None:
                    points.append({
                        "timestamp": t,
                        "value": round(v * cfg["scale"], 4),
                    })
    except Exception as exc:
        print(f"  WARNING [{key}]: {exc}", file=sys.stderr)

    points.sort(key=lambda p: p["timestamp"])
    return points


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Collect Cloud Run metrics from Cloud Monitoring and save as JSON."
    )
    parser.add_argument("--project", required=True, help="GCP project ID")
    parser.add_argument("--service", required=True, help="Cloud Run service name (e.g. device-api-go)")
    parser.add_argument("--start", required=True, help="Test start time (ISO 8601 UTC, e.g. 2026-05-12T10:00:00Z)")
    parser.add_argument("--end",   required=True, help="Test end time (ISO 8601 UTC)")
    parser.add_argument(
        "--region",
        default=os.environ.get("REGION", "europe-west8"),
        help="GCP region (default: europe-west8, override with REGION env var)",
    )
    parser.add_argument(
        "--out-dir",
        default=os.path.join(os.path.dirname(__file__), "results"),
        help="Directory to write the JSON file (default: ./results/)",
    )
    args = parser.parse_args()

    start_dt = parse_iso(args.start).astimezone(timezone.utc)
    end_dt   = parse_iso(args.end).astimezone(timezone.utc)

    if end_dt <= start_dt:
        print("ERROR: --end must be after --start", file=sys.stderr)
        sys.exit(1)

    print(f"Service  : {args.service}")
    print(f"Project  : {args.project}")
    print(f"Region   : {args.region}")
    print(f"Interval : {start_dt.isoformat()} → {end_dt.isoformat()}")
    print()

    client = monitoring_v3.MetricServiceClient()

    result = {
        "service": args.service,
        "project": args.project,
        "region":  args.region,
        "start":   start_dt.isoformat(),
        "end":     end_dt.isoformat(),
        "metrics": {},
    }

    for key, cfg in METRICS.items():
        print(f"  Querying {key:<30}", end=" ", flush=True)
        points = collect_metric(
            client, args.project, args.service, args.region,
            key, cfg, start_dt, end_dt,
        )
        result["metrics"][key] = {"unit": cfg["unit"], "points": points}
        print(f"→ {len(points)} point(s)")

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    safe_start = args.start.replace(":", "").replace("Z", "").replace("+0000", "")
    out_file = out_dir / f"{args.service}_{safe_start}.json"
    out_file.write_text(json.dumps(result, indent=2))

    print(f"\nSaved → {out_file}")


if __name__ == "__main__":
    main()
