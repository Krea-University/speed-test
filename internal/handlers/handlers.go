// Package handlers contains all HTTP request handlers for the speed test server
package handlers

import (
	"crypto/rand"
	"encoding/json"
	"io"
	"log"
	"net"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/Krea-University/speed-test/internal/config"
	"github.com/Krea-University/speed-test/internal/database"
	"github.com/Krea-University/speed-test/internal/ipservice"
	"github.com/Krea-University/speed-test/internal/models"
	"github.com/Krea-University/speed-test/internal/types"
	"github.com/gorilla/mux"
	"github.com/gorilla/websocket"
	"github.com/google/uuid"
)

// Handlers contains all HTTP handlers and their dependencies
type Handlers struct {
	ipService *ipservice.Service
	db        *database.Service
	upgrader  websocket.Upgrader
}

// New creates a new handlers instance with dependencies
func New(db *database.Service) *Handlers {
	return &Handlers{
		ipService: ipservice.NewService(),
		db:        db,
		upgrader: websocket.Upgrader{
			CheckOrigin: func(r *http.Request) bool {
				return true // Allow all origins for testing purposes
			},
		},
	}
}

// Ping returns server timestamp for latency measurement
// @Summary Ping endpoint for latency measurement
// @Description Returns server timestamp in nanoseconds for latency calculation
// @Tags Speed Test
// @Produce json
// @Success 200 {object} types.PingResponse
// @Router /ping [get]
func (h *Handlers) Ping(w http.ResponseWriter, r *http.Request) {
	start := time.Now()
	response := types.PingResponse{
		Timestamp: time.Now().UnixNano(),
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(response); err != nil {
		log.Printf("Error encoding ping response: %v", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	// Store ping test result
	if h.db != nil {
		clientIP := getClientIP(r)
		latency := float64(time.Since(start).Nanoseconds()) / 1000000 // Convert to milliseconds
		
		test := models.NewSpeedTest(clientIP, "ping")
		test.PingLatencyMs = &latency
		userAgent := r.UserAgent()
		test.UserAgent = &userAgent
		
		// Get IP info
		if ipInfo, err := h.ipService.GetIPInfo(clientIP); err == nil {
			test.ISP = &ipInfo.ISP
			test.Country = &ipInfo.Country
			test.Region = &ipInfo.Region
			test.City = &ipInfo.City
		}
		
		go h.db.CreateSpeedTest(test) // Store asynchronously
	}
}

// Download streams random data for download speed testing
// GET /download?size=BYTES
func (h *Handlers) Download(w http.ResponseWriter, r *http.Request) {
	// Parse size parameter, default to configured default
	sizeStr := r.URL.Query().Get("size")
	size := config.DefaultDownloadSize

	if sizeStr != "" {
		if parsedSize, err := strconv.Atoi(sizeStr); err == nil && parsedSize > 0 {
			// Limit maximum download size to prevent abuse
			if parsedSize > config.MaxUploadSize {
				parsedSize = config.MaxUploadSize
			}
			size = parsedSize
		}
	}

	// Set appropriate headers for binary data streaming
	w.Header().Set("Content-Type", "application/octet-stream")
	w.Header().Set("Content-Length", strconv.Itoa(size))
	w.Header().Set("Cache-Control", "no-cache, no-store, must-revalidate")
	w.Header().Set("Pragma", "no-cache")
	w.Header().Set("Expires", "0")

	// Stream random data in chunks
	buffer := make([]byte, config.BufferSize)
	written := 0

	for written < size {
		chunkSize := len(buffer)
		if written+chunkSize > size {
			chunkSize = size - written
		}

		// Generate cryptographically secure random data
		if _, err := rand.Read(buffer[:chunkSize]); err != nil {
			log.Printf("Error generating random data: %v", err)
			http.Error(w, "Internal server error", http.StatusInternalServerError)
			return
		}

		n, err := w.Write(buffer[:chunkSize])
		if err != nil {
			log.Printf("Error writing download data: %v", err)
			return
		}

		written += n

		// Flush to ensure streaming behavior
		if flusher, ok := w.(http.Flusher); ok {
			flusher.Flush()
		}
	}
}

// Upload accepts data and returns bytes received for upload speed testing
// POST /upload
func (h *Handlers) Upload(w http.ResponseWriter, r *http.Request) {
	// Limit the request body size to prevent abuse
	r.Body = http.MaxBytesReader(w, r.Body, int64(config.MaxUploadSize))

	// Count bytes received while discarding the data
	bytesReceived, err := io.Copy(io.Discard, r.Body)
	if err != nil {
		log.Printf("Error reading upload data: %v", err)
		http.Error(w, "Error reading request body", http.StatusBadRequest)
		return
	}

	response := types.UploadResponse{
		BytesReceived: bytesReceived,
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(response); err != nil {
		log.Printf("Error encoding upload response: %v", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
	}
}

// WebSocket provides WebSocket endpoint for jitter measurement
// GET /ws
func (h *Handlers) WebSocket(w http.ResponseWriter, r *http.Request) {
	conn, err := h.upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("WebSocket upgrade error: %v", err)
		return
	}
	defer conn.Close()

	// Handle WebSocket messages
	for {
		messageType, message, err := conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("WebSocket error: %v", err)
			}
			break
		}

		// Echo message back with current timestamp for jitter calculation
		response := types.WebSocketResponse{
			Timestamp: time.Now().UnixNano(),
			Echo:      string(message),
		}

		responseData, err := json.Marshal(response)
		if err != nil {
			log.Printf("Error marshaling WebSocket response: %v", err)
			break
		}

		if err := conn.WriteMessage(messageType, responseData); err != nil {
			log.Printf("WebSocket write error: %v", err)
			break
		}
	}
}

// IP returns client IP and comprehensive geolocation information
// GET /ip
func (h *Handlers) IP(w http.ResponseWriter, r *http.Request) {
	clientIP := getClientIP(r)

	// Try to get detailed IP information using the IP service
	response, err := h.ipService.GetIPInfo(clientIP)
	if err != nil {
		log.Printf("Failed to get IP info for %s: %v", clientIP, err)
		// Return basic response with just the IP
		response = &types.IPResponse{
			IP:     clientIP,
			Source: "local",
		}
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(response); err != nil {
		log.Printf("Error encoding IP response: %v", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
	}
}

// Health provides health check endpoint
// GET /healthz
func (h *Handlers) Health(w http.ResponseWriter, r *http.Request) {
	response := types.HealthResponse{
		Status: "ok",
		Time:   time.Now().UTC().Format(time.RFC3339),
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(response); err != nil {
		log.Printf("Error encoding health response: %v", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
	}
}

// Version returns application version information
// GET /version
func (h *Handlers) Version(w http.ResponseWriter, r *http.Request) {
	response := map[string]string{
		"version": config.Version,
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(response); err != nil {
		log.Printf("Error encoding version response: %v", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
	}
}

// Config returns server configuration for clients
// GET /config
func (h *Handlers) Config(w http.ResponseWriter, r *http.Request) {
	response := types.Config{
		DefaultDownloadSize: config.DefaultDownloadSize,
		Version:            config.Version,
		MaxUploadSize:      config.MaxUploadSize,
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(response); err != nil {
		log.Printf("Error encoding config response: %v", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
	}
}

// getClientIP extracts the real client IP from the request headers
// It checks various headers that might contain the real IP when behind proxies
func getClientIP(r *http.Request) string {
	// Check X-Forwarded-For header (most common)
	xForwardedFor := r.Header.Get("X-Forwarded-For")
	if xForwardedFor != "" {
		// X-Forwarded-For can contain multiple IPs (client, proxy1, proxy2, ...)
		// Take the first one which should be the original client
		ips := strings.Split(xForwardedFor, ",")
		clientIP := strings.TrimSpace(ips[0])
		if clientIP != "" {
			return clientIP
		}
	}

	// Check X-Real-IP header (used by some proxies)
	xRealIP := r.Header.Get("X-Real-IP")
	if xRealIP != "" {
		return strings.TrimSpace(xRealIP)
	}

	// Check X-Client-IP header (less common)
	xClientIP := r.Header.Get("X-Client-IP")
	if xClientIP != "" {
		return strings.TrimSpace(xClientIP)
	}

	// Fall back to RemoteAddr (direct connection)
	ip, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		// If SplitHostPort fails, return the RemoteAddr as-is
		return r.RemoteAddr
	}

	return ip
}

// API Endpoints for managing speed tests

// CreateSpeedTest creates a new speed test record
// @Summary Create a new speed test
// @Description Creates a new speed test record and returns the test ID
// @Tags API
// @Accept json
// @Produce json
// @Param test body models.SpeedTest true "Speed test data"
// @Success 201 {object} map[string]string
// @Failure 400 {object} map[string]string
// @Failure 500 {object} map[string]string
// @Security ApiKeyAuth
// @Router /api/tests [post]
func (h *Handlers) CreateSpeedTest(w http.ResponseWriter, r *http.Request) {
	var test models.SpeedTest
	if err := json.NewDecoder(r.Body).Decode(&test); err != nil {
		http.Error(w, `{"error":"Invalid JSON"}`, http.StatusBadRequest)
		return
	}

	// Generate new ID if not provided
	if test.ID == "" {
		test.ID = uuid.New().String()
	}

	// Set timestamps
	now := time.Now()
	test.CreatedAt = now
	test.UpdatedAt = now

	// Set client IP if not provided
	if test.ClientIP == "" {
		test.ClientIP = getClientIP(r)
	}

	if err := h.db.CreateSpeedTest(&test); err != nil {
		log.Printf("Error creating speed test: %v", err)
		http.Error(w, `{"error":"Failed to create speed test"}`, http.StatusInternalServerError)
		return
	}

	response := map[string]string{
		"id":      test.ID,
		"message": "Speed test created successfully",
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(response)
}

// GetSpeedTest retrieves a speed test by ID
// @Summary Get speed test by ID
// @Description Retrieves a specific speed test record by its ID
// @Tags API
// @Produce json
// @Param id path string true "Speed test ID"
// @Success 200 {object} models.SpeedTest
// @Failure 404 {object} map[string]string
// @Failure 500 {object} map[string]string
// @Security ApiKeyAuth
// @Router /api/tests/{id} [get]
func (h *Handlers) GetSpeedTest(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	id := vars["id"]

	if id == "" {
		http.Error(w, `{"error":"ID parameter required"}`, http.StatusBadRequest)
		return
	}

	test, err := h.db.GetSpeedTest(id)
	if err != nil {
		if strings.Contains(err.Error(), "not found") {
			http.Error(w, `{"error":"Speed test not found"}`, http.StatusNotFound)
		} else {
			log.Printf("Error getting speed test: %v", err)
			http.Error(w, `{"error":"Internal server error"}`, http.StatusInternalServerError)
		}
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(test)
}

// GetAllSpeedTests retrieves all speed tests with pagination
// @Summary Get all speed tests
// @Description Retrieves all speed test records with pagination support
// @Tags API
// @Produce json
// @Param limit query int false "Number of records to return" default(50)
// @Param offset query int false "Number of records to skip" default(0)
// @Success 200 {array} models.SpeedTest
// @Failure 400 {object} map[string]string
// @Failure 500 {object} map[string]string
// @Security ApiKeyAuth
// @Router /api/tests [get]
func (h *Handlers) GetAllSpeedTests(w http.ResponseWriter, r *http.Request) {
	// Parse pagination parameters
	limitStr := r.URL.Query().Get("limit")
	offsetStr := r.URL.Query().Get("offset")

	limit := 50 // default
	if limitStr != "" {
		if l, err := strconv.Atoi(limitStr); err == nil && l > 0 && l <= 1000 {
			limit = l
		}
	}

	offset := 0 // default
	if offsetStr != "" {
		if o, err := strconv.Atoi(offsetStr); err == nil && o >= 0 {
			offset = o
		}
	}

	tests, err := h.db.GetAllSpeedTests(limit, offset)
	if err != nil {
		log.Printf("Error getting speed tests: %v", err)
		http.Error(w, `{"error":"Failed to retrieve speed tests"}`, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(tests)
}

// GetSpeedTestOokla retrieves a speed test in Ookla-compatible format
// @Summary Get speed test in Ookla format
// @Description Retrieves a speed test result in Ookla speedtest.net compatible format
// @Tags Public
// @Produce json
// @Param id path string true "Speed test ID"
// @Success 200 {object} models.OoklaCompatibleResponse
// @Failure 404 {object} map[string]string
// @Failure 500 {object} map[string]string
// @Router /result/{id} [get]
func (h *Handlers) GetSpeedTestOokla(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	id := vars["id"]

	if id == "" {
		http.Error(w, `{"error":"ID parameter required"}`, http.StatusBadRequest)
		return
	}

	test, err := h.db.GetSpeedTest(id)
	if err != nil {
		if strings.Contains(err.Error(), "not found") {
			http.Error(w, `{"error":"Speed test not found"}`, http.StatusNotFound)
		} else {
			log.Printf("Error getting speed test: %v", err)
			http.Error(w, `{"error":"Internal server error"}`, http.StatusInternalServerError)
		}
		return
	}

	// Convert to Ookla format
	ooklaResponse := test.ToOoklaFormat()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(ooklaResponse)
}
