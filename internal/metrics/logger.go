// Package metrics provides persistent metrics logging for the speed test server
package metrics

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"sync"
	"time"

	"github.com/Krea-University/speed-test-server/internal/database"
)

// Metric represents a single metric measurement
type Metric struct {
	ID        string    `json:"id" db:"id"`
	Timestamp time.Time `json:"timestamp" db:"timestamp"`
	Type      string    `json:"type" db:"type"`
	ClientIP  string    `json:"client_ip" db:"client_ip"`
	UserAgent string    `json:"user_agent" db:"user_agent"`
	Location  string    `json:"location,omitempty" db:"location"`

	// Speed test metrics
	LatencyMs    float64 `json:"latency_ms,omitempty" db:"latency_ms"`
	JitterMs     float64 `json:"jitter_ms,omitempty" db:"jitter_ms"`
	DownloadMbps float64 `json:"download_mbps,omitempty" db:"download_mbps"`
	UploadMbps   float64 `json:"upload_mbps,omitempty" db:"upload_mbps"`

	// Test parameters
	TestDuration int64 `json:"test_duration_ms,omitempty" db:"test_duration_ms"`
	DataSize     int64 `json:"data_size_bytes,omitempty" db:"data_size_bytes"`
	ChunkCount   int   `json:"chunk_count,omitempty" db:"chunk_count"`

	// Server metrics
	ServerLoad      float64 `json:"server_load,omitempty" db:"server_load"`
	ConcurrentUsers int     `json:"concurrent_users,omitempty" db:"concurrent_users"`
	ErrorCode       string  `json:"error_code,omitempty" db:"error_code"`
	ErrorMessage    string  `json:"error_message,omitempty" db:"error_message"`
}

// MetricsLogger handles persistent logging of metrics
type MetricsLogger struct {
	db       *database.Service
	logFile  *os.File
	logPath  string
	mu       sync.RWMutex
	buffer   []Metric
	flushInt time.Duration
	stopChan chan struct{}
}

// NewMetricsLogger creates a new metrics logger
func NewMetricsLogger(db *database.Service, logDir string) (*MetricsLogger, error) {
	// Ensure log directory exists
	if err := os.MkdirAll(logDir, 0755); err != nil {
		return nil, fmt.Errorf("failed to create log directory: %w", err)
	}

	// Create log file with timestamp
	logPath := filepath.Join(logDir, fmt.Sprintf("metrics_%s.jsonl",
		time.Now().Format("2006-01-02")))

	logFile, err := os.OpenFile(logPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
	if err != nil {
		return nil, fmt.Errorf("failed to open log file: %w", err)
	}

	logger := &MetricsLogger{
		db:       db,
		logFile:  logFile,
		logPath:  logPath,
		buffer:   make([]Metric, 0, 100),
		flushInt: 30 * time.Second,
		stopChan: make(chan struct{}),
	}

	// Start background flusher
	go logger.backgroundFlusher()

	log.Printf("Metrics logger initialized: %s", logPath)
	return logger, nil
}

// LogSpeedTest logs a speed test metric
func (ml *MetricsLogger) LogSpeedTest(clientIP, userAgent, location string,
	latency, jitter, download, upload float64, duration, dataSize int64, chunks int) {

	metric := Metric{
		ID:              generateID(),
		Timestamp:       time.Now().UTC(),
		Type:            "speed_test",
		ClientIP:        clientIP,
		UserAgent:       userAgent,
		Location:        location,
		LatencyMs:       latency,
		JitterMs:        jitter,
		DownloadMbps:    download,
		UploadMbps:      upload,
		TestDuration:    duration,
		DataSize:        dataSize,
		ChunkCount:      chunks,
		ServerLoad:      getCurrentLoad(),
		ConcurrentUsers: getConcurrentUsers(),
	}

	ml.addMetric(metric)
}

// LogServerMetric logs general server metrics
func (ml *MetricsLogger) LogServerMetric(metricType string, value float64, metadata map[string]interface{}) {
	metric := Metric{
		ID:              generateID(),
		Timestamp:       time.Now().UTC(),
		Type:            metricType,
		ServerLoad:      getCurrentLoad(),
		ConcurrentUsers: getConcurrentUsers(),
	}

	// Add metadata as JSON in error_message field for flexibility
	if len(metadata) > 0 {
		if data, err := json.Marshal(metadata); err == nil {
			metric.ErrorMessage = string(data)
		}
	}

	ml.addMetric(metric)
}

// LogError logs an error metric
func (ml *MetricsLogger) LogError(clientIP, userAgent, errorCode, errorMessage string) {
	metric := Metric{
		ID:              generateID(),
		Timestamp:       time.Now().UTC(),
		Type:            "error",
		ClientIP:        clientIP,
		UserAgent:       userAgent,
		ErrorCode:       errorCode,
		ErrorMessage:    errorMessage,
		ServerLoad:      getCurrentLoad(),
		ConcurrentUsers: getConcurrentUsers(),
	}

	ml.addMetric(metric)
}

// addMetric adds a metric to the buffer
func (ml *MetricsLogger) addMetric(metric Metric) {
	ml.mu.Lock()
	defer ml.mu.Unlock()

	ml.buffer = append(ml.buffer, metric)

	// Immediate flush for errors or if buffer is full
	if metric.Type == "error" || len(ml.buffer) >= 50 {
		go ml.flush()
	}
}

// flush writes buffered metrics to storage
func (ml *MetricsLogger) flush() {
	ml.mu.Lock()
	if len(ml.buffer) == 0 {
		ml.mu.Unlock()
		return
	}

	// Get copy of buffer and clear it
	metrics := make([]Metric, len(ml.buffer))
	copy(metrics, ml.buffer)
	ml.buffer = ml.buffer[:0]
	ml.mu.Unlock()

	// Write to file
	ml.writeToFile(metrics)

	// Write to database if available
	if ml.db != nil {
		ml.writeToDatabase(metrics)
	}
}

// writeToFile writes metrics to JSON lines file
func (ml *MetricsLogger) writeToFile(metrics []Metric) {
	for _, metric := range metrics {
		if data, err := json.Marshal(metric); err == nil {
			fmt.Fprintf(ml.logFile, "%s\n", data)
		}
	}
	ml.logFile.Sync()
}

// writeToDatabase writes metrics to database
func (ml *MetricsLogger) writeToDatabase(metrics []Metric) {
	for _, metric := range metrics {
		if err := ml.db.CreateMetric(metric); err != nil {
			log.Printf("Failed to save metric to database: %v", err)
		}
	}
}

// backgroundFlusher periodically flushes metrics
func (ml *MetricsLogger) backgroundFlusher() {
	ticker := time.NewTicker(ml.flushInt)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			ml.flush()
		case <-ml.stopChan:
			ml.flush() // Final flush
			return
		}
	}
}

// GetMetrics retrieves metrics from storage
func (ml *MetricsLogger) GetMetrics(metricType string, startTime, endTime time.Time, limit int) ([]Metric, error) {
	if ml.db != nil {
		// Get data from database and convert to metrics format
		dbMetrics, err := ml.db.GetMetrics(metricType, startTime, endTime, limit)
		if err != nil {
			return nil, err
		}

		// Convert interface{} slice to Metric slice
		// For now, return empty slice as placeholder
		// In production, implement proper conversion
		var metrics []Metric
		_ = dbMetrics // silence unused variable warning
		return metrics, nil
	}

	// Fallback to file-based retrieval (simplified)
	return ml.getMetricsFromFile(metricType, startTime, endTime, limit)
}

// getMetricsFromFile reads metrics from log files
func (ml *MetricsLogger) getMetricsFromFile(metricType string, startTime, endTime time.Time, limit int) ([]Metric, error) {
	var metrics []Metric

	// This is a simplified implementation
	// In production, you might want to implement proper file indexing

	return metrics, nil
}

// GetServerStats returns aggregated server statistics
func (ml *MetricsLogger) GetServerStats(hours int) (*ServerStats, error) {
	endTime := time.Now().UTC()
	startTime := endTime.Add(-time.Duration(hours) * time.Hour)

	if ml.db != nil {
		dbStats, err := ml.db.GetServerStats(startTime, endTime)
		if err != nil {
			return nil, err
		}

		// Convert database.ServerStats to metrics.ServerStats
		return &ServerStats{
			TotalTests:      dbStats.TotalTests,
			AverageLatency:  dbStats.AverageLatency,
			AverageDownload: dbStats.AverageDownload,
			AverageUpload:   dbStats.AverageUpload,
			PeakConcurrent:  dbStats.PeakConcurrent,
			ErrorRate:       dbStats.ErrorRate,
			Timestamp:       dbStats.Timestamp,
		}, nil
	}

	// Fallback implementation
	return &ServerStats{
		TotalTests:      0,
		AverageLatency:  0,
		AverageDownload: 0,
		AverageUpload:   0,
		PeakConcurrent:  0,
		ErrorRate:       0,
	}, nil
}

// ServerStats represents aggregated server statistics
type ServerStats struct {
	TotalTests      int64     `json:"total_tests"`
	AverageLatency  float64   `json:"average_latency_ms"`
	AverageDownload float64   `json:"average_download_mbps"`
	AverageUpload   float64   `json:"average_upload_mbps"`
	PeakConcurrent  int       `json:"peak_concurrent_users"`
	ErrorRate       float64   `json:"error_rate_percent"`
	Timestamp       time.Time `json:"timestamp"`
}

// Close closes the metrics logger
func (ml *MetricsLogger) Close() error {
	close(ml.stopChan)
	ml.flush()
	return ml.logFile.Close()
}

// Helper functions
func generateID() string {
	return fmt.Sprintf("%d-%d", time.Now().UnixNano(), os.Getpid())
}

func getCurrentLoad() float64 {
	// Simplified load calculation
	// In production, you might want to use actual system metrics
	return 0.5 // Placeholder
}

func getConcurrentUsers() int {
	// This should be tracked by your server
	// Placeholder implementation
	return 1
}
