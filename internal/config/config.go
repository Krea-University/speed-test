// Package config handles application configuration and constants
package config

import (
	"os"
	"strconv"
)

const (
	// DefaultDownloadSize is the default size for download speed tests (50 MiB)
	DefaultDownloadSize = 50 * 1024 * 1024

	// Version represents the current application version
	Version = "1.0.0"

	// DefaultPort is the default HTTP server port
	DefaultPort = "8080"

	// BufferSize is the size of the buffer used for streaming data (32KB)
	BufferSize = 32 * 1024

	// MaxUploadSize is the maximum allowed upload size (100 MiB)
	MaxUploadSize = 100 * 1024 * 1024

	// HTTPTimeout is the timeout for external HTTP requests
	HTTPTimeout = 5

	// MaxConcurrentRequests is the maximum number of concurrent requests allowed
	// Set to 0 to disable concurrent request limiting
	MaxConcurrentRequests = 0
)

// GetMaxConcurrentRequests returns the maximum concurrent requests from environment or default
func GetMaxConcurrentRequests() int {
	if maxReqsStr := os.Getenv("MAX_CONCURRENT_REQUESTS"); maxReqsStr != "" {
		if maxReqs, err := strconv.Atoi(maxReqsStr); err == nil && maxReqs > 0 {
			return maxReqs
		}
	}
	return MaxConcurrentRequests
}
