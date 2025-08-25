// Package types defines all data structures used across the application
package types

// Config represents the server configuration that can be shared with clients
type Config struct {
	DefaultDownloadSize int    `json:"default_download_size"` // Default download size in bytes
	Version            string `json:"version"`               // Application version
	MaxUploadSize      int    `json:"max_upload_size"`       // Maximum upload size in bytes
}

// PingResponse represents the response from the ping endpoint
type PingResponse struct {
	Timestamp int64 `json:"timestamp"` // Server timestamp in nanoseconds
}

// IPResponse represents the comprehensive IP information response
type IPResponse struct {
	IP       string `json:"ip"`                 // Client IP address
	ASN      string `json:"asn,omitempty"`      // Autonomous System Number
	ISP      string `json:"isp,omitempty"`      // Internet Service Provider
	Location string `json:"location,omitempty"` // Geographic coordinates (lat,lng)
	City     string `json:"city,omitempty"`     // City name
	Region   string `json:"region,omitempty"`   // Region/State name
	Country  string `json:"country,omitempty"`  // Country code
	Postal   string `json:"postal,omitempty"`   // Postal/ZIP code
	Timezone string `json:"timezone,omitempty"` // Timezone
	Source   string `json:"source,omitempty"`   // Data source (ipinfo, ip-api, etc.)
}

// UploadResponse represents the response from the upload endpoint
type UploadResponse struct {
	BytesReceived int64 `json:"bytes_received"` // Total bytes received
}

// HealthResponse represents the health check response
type HealthResponse struct {
	Status string `json:"status"` // Health status ("ok" or "error")
	Time   string `json:"time"`   // Current server time in RFC3339 format
}

// WebSocketResponse represents a WebSocket message response
type WebSocketResponse struct {
	Timestamp int64  `json:"timestamp"` // Server timestamp in nanoseconds
	Echo      string `json:"echo"`      // Echoed message from client
}
