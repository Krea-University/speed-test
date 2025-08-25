package main

import (
	"bytes"
	"crypto/rand"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

const (
	ServerURL = "http://localhost:8080"
)

type PingResponse struct {
	Timestamp int64 `json:"timestamp"`
}

type UploadResponse struct {
	BytesReceived int64 `json:"bytes_received"`
}

func main() {
	fmt.Println("Speed Test Client")
	fmt.Println("=================")

	// Test latency
	fmt.Println("\n1. Testing Latency...")
	testLatency()

	// Test download speed
	fmt.Println("\n2. Testing Download Speed...")
	testDownload()

	// Test upload speed
	fmt.Println("\n3. Testing Upload Speed...")
	testUpload()

	// Get IP info
	fmt.Println("\n4. Getting IP Information...")
	getIPInfo()
}

func testLatency() {
	const numPings = 5
	var totalLatency time.Duration

	for i := 0; i < numPings; i++ {
		start := time.Now()

		resp, err := http.Get(ServerURL + "/ping")
		if err != nil {
			fmt.Printf("Error: %v\n", err)
			return
		}

		var pingResp PingResponse
		json.NewDecoder(resp.Body).Decode(&pingResp)
		resp.Body.Close()

		latency := time.Since(start)
		totalLatency += latency

		fmt.Printf("Ping %d: %v\n", i+1, latency)
	}

	avgLatency := totalLatency / numPings
	fmt.Printf("Average latency: %v\n", avgLatency)
}

func testDownload() {
	sizes := []int{1024 * 1024, 10 * 1024 * 1024} // 1MB, 10MB

	for _, size := range sizes {
		fmt.Printf("Testing download of %d bytes...\n", size)

		start := time.Now()
		resp, err := http.Get(fmt.Sprintf("%s/download?size=%d", ServerURL, size))
		if err != nil {
			fmt.Printf("Error: %v\n", err)
			continue
		}

		bytesRead, err := io.Copy(io.Discard, resp.Body)
		if err != nil {
			fmt.Printf("Error reading response: %v\n", err)
			resp.Body.Close()
			continue
		}
		resp.Body.Close()

		duration := time.Since(start)
		speedMbps := float64(bytesRead) * 8 / duration.Seconds() / 1000000

		fmt.Printf("Downloaded %d bytes in %v (%.2f Mbps)\n", bytesRead, duration, speedMbps)
	}
}

func testUpload() {
	sizes := []int{1024 * 1024, 5 * 1024 * 1024} // 1MB, 5MB

	for _, size := range sizes {
		fmt.Printf("Testing upload of %d bytes...\n", size)

		// Generate random data
		data := make([]byte, size)
		rand.Read(data)

		start := time.Now()
		resp, err := http.Post(ServerURL+"/upload", "application/octet-stream", bytes.NewReader(data))
		if err != nil {
			fmt.Printf("Error: %v\n", err)
			continue
		}

		var uploadResp UploadResponse
		json.NewDecoder(resp.Body).Decode(&uploadResp)
		resp.Body.Close()

		duration := time.Since(start)
		speedMbps := float64(uploadResp.BytesReceived) * 8 / duration.Seconds() / 1000000

		fmt.Printf("Uploaded %d bytes in %v (%.2f Mbps)\n", uploadResp.BytesReceived, duration, speedMbps)
	}
}

func getIPInfo() {
	resp, err := http.Get(ServerURL + "/ip")
	if err != nil {
		fmt.Printf("Error: %v\n", err)
		return
	}
	defer resp.Body.Close()

	var ipInfo map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&ipInfo)

	fmt.Printf("Your IP: %v\n", ipInfo["ip"])
}
