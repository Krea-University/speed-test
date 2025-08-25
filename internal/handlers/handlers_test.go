// Package handlers_test provides comprehensive tests for all HTTP handlers
package handlers_test

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/Krea-University/speed-test-server/internal/handlers"
	"github.com/Krea-University/speed-test-server/internal/types"
)

func TestPingHandler(t *testing.T) {
	h := handlers.New(nil)

	req, err := http.NewRequest("GET", "/ping", nil)
	if err != nil {
		t.Fatal(err)
	}

	rr := httptest.NewRecorder()
	h.Ping(rr, req)

	if status := rr.Code; status != http.StatusOK {
		t.Errorf("handler returned wrong status code: got %v want %v",
			status, http.StatusOK)
	}

	var response types.PingResponse
	if err := json.Unmarshal(rr.Body.Bytes(), &response); err != nil {
		t.Errorf("failed to unmarshal response: %v", err)
	}

	// Check if timestamp is reasonable (within last second)
	now := time.Now().UnixNano()
	if response.Timestamp > now || response.Timestamp < now-1e9 {
		t.Errorf("timestamp seems unreasonable: %d", response.Timestamp)
	}
}

func TestHealthHandler(t *testing.T) {
	h := handlers.New(nil)

	req, err := http.NewRequest("GET", "/healthz", nil)
	if err != nil {
		t.Fatal(err)
	}

	rr := httptest.NewRecorder()
	h.Health(rr, req)

	if status := rr.Code; status != http.StatusOK {
		t.Errorf("handler returned wrong status code: got %v want %v",
			status, http.StatusOK)
	}

	var response types.HealthResponse
	if err := json.Unmarshal(rr.Body.Bytes(), &response); err != nil {
		t.Errorf("failed to unmarshal response: %v", err)
	}

	if response.Status != "ok" {
		t.Errorf("expected status 'ok', got '%s'", response.Status)
	}
}

func TestUploadHandler(t *testing.T) {
	h := handlers.New(nil)

	testData := []byte("test upload data")
	req, err := http.NewRequest("POST", "/upload", bytes.NewBuffer(testData))
	if err != nil {
		t.Fatal(err)
	}

	rr := httptest.NewRecorder()
	h.Upload(rr, req)

	if status := rr.Code; status != http.StatusOK {
		t.Errorf("handler returned wrong status code: got %v want %v",
			status, http.StatusOK)
	}

	var response types.UploadResponse
	if err := json.Unmarshal(rr.Body.Bytes(), &response); err != nil {
		t.Errorf("failed to unmarshal response: %v", err)
	}

	if response.BytesReceived != int64(len(testData)) {
		t.Errorf("expected %d bytes received, got %d", len(testData), response.BytesReceived)
	}
}

func TestVersionHandler(t *testing.T) {
	h := handlers.New(nil)

	req, err := http.NewRequest("GET", "/version", nil)
	if err != nil {
		t.Fatal(err)
	}

	rr := httptest.NewRecorder()
	h.Version(rr, req)

	if status := rr.Code; status != http.StatusOK {
		t.Errorf("handler returned wrong status code: got %v want %v",
			status, http.StatusOK)
	}

	var response map[string]string
	if err := json.Unmarshal(rr.Body.Bytes(), &response); err != nil {
		t.Errorf("failed to unmarshal response: %v", err)
	}

	if _, exists := response["version"]; !exists {
		t.Errorf("version field missing from response")
	}
}

func TestDownloadHandler(t *testing.T) {
	h := handlers.New(nil)

	req, err := http.NewRequest("GET", "/download?size=1024", nil)
	if err != nil {
		t.Fatal(err)
	}

	rr := httptest.NewRecorder()
	h.Download(rr, req)

	if status := rr.Code; status != http.StatusOK {
		t.Errorf("handler returned wrong status code: got %v want %v",
			status, http.StatusOK)
	}

	if len(rr.Body.Bytes()) != 1024 {
		t.Errorf("expected 1024 bytes, got %d", len(rr.Body.Bytes()))
	}

	contentType := rr.Header().Get("Content-Type")
	if contentType != "application/octet-stream" {
		t.Errorf("expected content type 'application/octet-stream', got '%s'", contentType)
	}
}

func TestIPHandler(t *testing.T) {
	h := handlers.New(nil)

	req, err := http.NewRequest("GET", "/ip", nil)
	if err != nil {
		t.Fatal(err)
	}

	// Set a test IP in the X-Forwarded-For header
	req.Header.Set("X-Forwarded-For", "8.8.8.8")

	rr := httptest.NewRecorder()
	h.IP(rr, req)

	if status := rr.Code; status != http.StatusOK {
		t.Errorf("handler returned wrong status code: got %v want %v",
			status, http.StatusOK)
	}

	var response types.IPResponse
	if err := json.Unmarshal(rr.Body.Bytes(), &response); err != nil {
		t.Errorf("failed to unmarshal response: %v", err)
	}

	if response.IP != "8.8.8.8" {
		t.Errorf("expected IP '8.8.8.8', got '%s'", response.IP)
	}
}

func TestConfigHandler(t *testing.T) {
	h := handlers.New(nil)

	req, err := http.NewRequest("GET", "/config", nil)
	if err != nil {
		t.Fatal(err)
	}

	rr := httptest.NewRecorder()
	h.Config(rr, req)

	if status := rr.Code; status != http.StatusOK {
		t.Errorf("handler returned wrong status code: got %v want %v",
			status, http.StatusOK)
	}

	var response types.Config
	if err := json.Unmarshal(rr.Body.Bytes(), &response); err != nil {
		t.Errorf("failed to unmarshal response: %v", err)
	}

	if response.DefaultDownloadSize <= 0 {
		t.Errorf("expected positive default download size, got %d", response.DefaultDownloadSize)
	}

	if response.Version == "" {
		t.Errorf("expected non-empty version")
	}
}
