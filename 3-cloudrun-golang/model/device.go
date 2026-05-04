package model

import "time"

type Device struct {
	ID        string    `json:"id"`
	Name      string    `json:"name"`
	Status    string    `json:"status"`
	CreatedAt time.Time `json:"createdAt"`
}

type CreateDeviceRequest struct {
	Name   string `json:"name"`
	Status string `json:"status"`
}
