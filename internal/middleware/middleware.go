// Package middleware provides HTTP middleware for the speed test server
package middleware

import (
	"bufio"
	"fmt"
	"log"
	"net"
	"net/http"
	"time"
)

// CORS enables Cross-Origin Resource Sharing for all routes
// This allows the speed test to be accessed from web browsers
func CORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Allow requests from any origin
		w.Header().Set("Access-Control-Allow-Origin", "*")

		// Allow common HTTP methods
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")

		// Allow common headers including those used by the speed test
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization, Accept, Accept-Encoding, Accept-Language")

		// Allow credentials if needed
		w.Header().Set("Access-Control-Allow-Credentials", "true")

		// Expose custom headers
		w.Header().Set("Access-Control-Expose-Headers", "Content-Length, Content-Type")

		// Set max age for preflight requests
		w.Header().Set("Access-Control-Max-Age", "86400")

		// Handle preflight OPTIONS requests
		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		next.ServeHTTP(w, r)
	})
}

// Logging logs HTTP requests with method, URL, and response time
func Logging(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()

		// Create a response writer wrapper to capture status code
		wrapped := &responseWriter{ResponseWriter: w, statusCode: http.StatusOK}

		next.ServeHTTP(wrapped, r)

		duration := time.Since(start)
		log.Printf("%s %s %d %v", r.Method, r.URL.Path, wrapped.statusCode, duration)
	})
}

// responseWriter wraps http.ResponseWriter to capture the status code and preserve Hijacker interface
type responseWriter struct {
	http.ResponseWriter
	statusCode int
}

// WriteHeader captures the status code
func (rw *responseWriter) WriteHeader(code int) {
	rw.statusCode = code
	rw.ResponseWriter.WriteHeader(code)
}

// Hijack implements http.Hijacker interface for WebSocket support
func (rw *responseWriter) Hijack() (net.Conn, *bufio.ReadWriter, error) {
	if hijacker, ok := rw.ResponseWriter.(http.Hijacker); ok {
		return hijacker.Hijack()
	}
	return nil, nil, fmt.Errorf("underlying ResponseWriter does not implement http.Hijacker")
}

// Security adds basic security headers
func Security(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Prevent MIME type sniffing
		w.Header().Set("X-Content-Type-Options", "nosniff")

		// Enable XSS protection
		w.Header().Set("X-XSS-Protection", "1; mode=block")

		// Prevent clickjacking
		w.Header().Set("X-Frame-Options", "DENY")

		// Don't send referrer to other sites
		w.Header().Set("Referrer-Policy", "strict-origin-when-cross-origin")

		next.ServeHTTP(w, r)
	})
}

// ConcurrentRequestLimiter limits the number of concurrent requests
type ConcurrentRequestLimiter struct {
	semaphore chan struct{}
	maxReqs   int
}

// NewConcurrentRequestLimiter creates a new concurrent request limiter
func NewConcurrentRequestLimiter(maxRequests int) *ConcurrentRequestLimiter {
	if maxRequests <= 0 {
		// Return a limiter that doesn't actually limit when maxRequests is 0
		return &ConcurrentRequestLimiter{
			semaphore: nil, // No semaphore for unlimited requests
			maxReqs:   0,   // 0 indicates unlimited
		}
	}
	return &ConcurrentRequestLimiter{
		semaphore: make(chan struct{}, maxRequests),
		maxReqs:   maxRequests,
	}
}

// Middleware returns the HTTP middleware function
func (c *ConcurrentRequestLimiter) Middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Skip concurrent limiting for WebSocket upgrades to avoid hijacker issues
		if r.Header.Get("Upgrade") == "websocket" {
			next.ServeHTTP(w, r)
			return
		}

		// If maxReqs is 0, allow unlimited requests (no limiting)
		if c.maxReqs == 0 {
			next.ServeHTTP(w, r)
			return
		}

		// Try to acquire a slot for non-WebSocket requests
		select {
		case c.semaphore <- struct{}{}:
			// Got a slot, continue with the request
			defer func() { <-c.semaphore }() // Release the slot when done
			next.ServeHTTP(w, r)
		default:
			// No slots available, return 503 Service Unavailable
			w.Header().Set("Retry-After", "1")
			w.WriteHeader(http.StatusServiceUnavailable)
			w.Write([]byte("Server is busy. Please try again later."))
			log.Printf("Request rejected due to concurrent limit (%d active requests)", c.maxReqs)
		}
	})
}
