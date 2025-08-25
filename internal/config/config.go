// Package config handles application configuration and constants
package config

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
)
