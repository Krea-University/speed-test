// Krea Speed Test Server
//
// A lightweight, self-hosted internet speed testing service built in Go.
// Provides endpoints for measuring latency, jitter, download/upload speeds,
// and IP geolocation information with multiple provider fallbacks.
//
// Author: Krea University
// Version: 1.0.0
// License: MIT

package main

import (
	"log"

	"github.com/Krea-University/speed-test-server/internal/server"
)

func main() {
	// Create and start the server
	srv := server.New()

	// Start server with graceful shutdown handling
	if err := srv.Start(); err != nil {
		log.Fatalf("Server failed: %v", err)
	}
}
