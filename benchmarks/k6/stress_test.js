import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';
import { htmlReport } from 'https://raw.githubusercontent.com/benc-uk/k6-reporter/latest/dist/bundle.js';
import { textSummary } from 'https://jslib.k6.io/k6-summary/0.1.0/index.js';

// Custom metrics
const errorRate = new Rate('errors');
const createDuration = new Trend('create_duration', true);

// Configuration
// Can be run directly via: k6 run -e BASE_URL=http://... stress_test.js
// Or via wrapper: ./stress_test.sh <service-name>
const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';

export const options = {
  stages: [
    { duration: '30s', target: 50 },   // Warmup — JIT needs time to optimize hot paths on JVM
    { duration: '30s', target: 200 },  // Ramp-up
    { duration: '300s', target: 200 }, // Steady state — extended to ~5 min for Cloud Monitoring granularity (60s/point)
    { duration: '30s', target: 0 },    // Ramp-down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],
    errors: ['rate<0.05'], // Accept up to 5% error under pure stress
  },
};

export default function () {
  // Pure Stress Test: Only POSTs. This tests raw compute and avoids 
  // dependency on sequence or specific IDs which can fail in scaled environments.
  const payload = JSON.stringify({
    name: `stress-sensor-${__VU}-${__ITER}`,
    status: 'ACTIVE',
  });

  const res = http.post(`${BASE_URL}/api/devices`, payload, {
    headers: { 'Content-Type': 'application/json' },
  });

  createDuration.add(res.timings.duration);
  const ok = check(res, {
    'status is 201': (r) => r.status === 201,
  });
  errorRate.add(!ok);

  // Added sleep to stabilize RPS at ~2000 (200 VU * 10 req/s)
  // This allows meaningful latency measurement (p95) on a single vCPU.
  sleep(0.1);
}

export function handleSummary(data) {
  const reportFile = __ENV.REPORT_FILE || 'stress_report.html';
  return {
    [reportFile]: htmlReport(data),
    stdout: textSummary(data, { indent: ' ', enableColors: true }),
  };
}
