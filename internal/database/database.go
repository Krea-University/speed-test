// Package database provides database connection and operations
package database

import (
	"database/sql"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/Krea-University/speed-test-server/internal/models"
	_ "github.com/go-sql-driver/mysql"
)

// Service provides database operations
type Service struct {
	db *sql.DB
}

// New creates a new database service
func New() (*Service, error) {
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		// Build DSN from individual environment variables
		host := os.Getenv("DB_HOST")
		port := os.Getenv("DB_PORT")
		user := os.Getenv("DB_USER")
		password := os.Getenv("DB_PASSWORD")
		dbname := os.Getenv("DB_NAME")

		if host == "" {
			host = "localhost"
		}
		if port == "" {
			port = "3306"
		}
		if user == "" {
			user = "root"
		}
		if password == "" {
			password = "password"
		}
		if dbname == "" {
			dbname = "speedtest"
		}

		dsn = fmt.Sprintf("%s:%s@tcp(%s:%s)/%s?charset=utf8mb4&parseTime=True&loc=Local",
			user, password, host, port, dbname)
	}

	db, err := sql.Open("mysql", dsn)
	if err != nil {
		return nil, fmt.Errorf("failed to open database: %v", err)
	}

	// Configure connection pool
	db.SetMaxOpenConns(25)
	db.SetMaxIdleConns(5)
	db.SetConnMaxLifetime(5 * time.Minute)

	// Test connection
	if err := db.Ping(); err != nil {
		return nil, fmt.Errorf("failed to ping database: %v", err)
	}

	log.Println("Database connection established")
	return &Service{db: db}, nil
}

// Close closes the database connection
func (s *Service) Close() error {
	if s.db != nil {
		return s.db.Close()
	}
	return nil
}

// CreateSpeedTest inserts a new speed test record
func (s *Service) CreateSpeedTest(test *models.SpeedTest) error {
	query := `
		INSERT INTO speed_tests (
			id, client_ip, user_agent, test_type, download_speed_mbps, upload_speed_mbps,
			ping_latency_ms, jitter_ms, download_size_bytes, upload_size_bytes,
			test_duration_seconds, isp, country, region, city, server_name,
			server_country, server_city, sponsor, created_at, updated_at
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
	`

	_, err := s.db.Exec(query,
		test.ID, test.ClientIP, test.UserAgent, test.TestType,
		test.DownloadSpeedMbps, test.UploadSpeedMbps, test.PingLatencyMs, test.JitterMs,
		test.DownloadSizeBytes, test.UploadSizeBytes, test.TestDurationSeconds,
		test.ISP, test.Country, test.Region, test.City, test.ServerName,
		test.ServerCountry, test.ServerCity, test.Sponsor, test.CreatedAt, test.UpdatedAt,
	)

	if err != nil {
		return fmt.Errorf("failed to create speed test: %v", err)
	}

	return nil
}

// GetSpeedTest retrieves a speed test by ID
func (s *Service) GetSpeedTest(id string) (*models.SpeedTest, error) {
	query := `
		SELECT id, client_ip, user_agent, test_type, download_speed_mbps, upload_speed_mbps,
			   ping_latency_ms, jitter_ms, download_size_bytes, upload_size_bytes,
			   test_duration_seconds, isp, country, region, city, server_name,
			   server_country, server_city, sponsor, created_at, updated_at
		FROM speed_tests WHERE id = ?
	`

	test := &models.SpeedTest{}
	err := s.db.QueryRow(query, id).Scan(
		&test.ID, &test.ClientIP, &test.UserAgent, &test.TestType,
		&test.DownloadSpeedMbps, &test.UploadSpeedMbps, &test.PingLatencyMs, &test.JitterMs,
		&test.DownloadSizeBytes, &test.UploadSizeBytes, &test.TestDurationSeconds,
		&test.ISP, &test.Country, &test.Region, &test.City, &test.ServerName,
		&test.ServerCountry, &test.ServerCity, &test.Sponsor, &test.CreatedAt, &test.UpdatedAt,
	)

	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("speed test not found")
		}
		return nil, fmt.Errorf("failed to get speed test: %v", err)
	}

	return test, nil
}

// GetAllSpeedTests retrieves all speed tests with pagination
func (s *Service) GetAllSpeedTests(limit, offset int) ([]*models.SpeedTest, error) {
	query := `
		SELECT id, client_ip, user_agent, test_type, download_speed_mbps, upload_speed_mbps,
			   ping_latency_ms, jitter_ms, download_size_bytes, upload_size_bytes,
			   test_duration_seconds, isp, country, region, city, server_name,
			   server_country, server_city, sponsor, created_at, updated_at
		FROM speed_tests 
		ORDER BY created_at DESC 
		LIMIT ? OFFSET ?
	`

	rows, err := s.db.Query(query, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("failed to query speed tests: %v", err)
	}
	defer rows.Close()

	var tests []*models.SpeedTest
	for rows.Next() {
		test := &models.SpeedTest{}
		err := rows.Scan(
			&test.ID, &test.ClientIP, &test.UserAgent, &test.TestType,
			&test.DownloadSpeedMbps, &test.UploadSpeedMbps, &test.PingLatencyMs, &test.JitterMs,
			&test.DownloadSizeBytes, &test.UploadSizeBytes, &test.TestDurationSeconds,
			&test.ISP, &test.Country, &test.Region, &test.City, &test.ServerName,
			&test.ServerCountry, &test.ServerCity, &test.Sponsor, &test.CreatedAt, &test.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan speed test: %v", err)
		}
		tests = append(tests, test)
	}

	return tests, nil
}

// GetAPIKey retrieves an API key by hash
func (s *Service) GetAPIKey(keyHash string) (*models.APIKey, error) {
	query := `
		SELECT id, key_hash, name, description, rate_limit_per_minute, is_active, created_at, last_used_at
		FROM api_keys WHERE key_hash = ? AND is_active = true
	`

	key := &models.APIKey{}
	err := s.db.QueryRow(query, keyHash).Scan(
		&key.ID, &key.KeyHash, &key.Name, &key.Description,
		&key.RateLimitPerMinute, &key.IsActive, &key.CreatedAt, &key.LastUsedAt,
	)

	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("API key not found")
		}
		return nil, fmt.Errorf("failed to get API key: %v", err)
	}

	return key, nil
}

// UpdateAPIKeyLastUsed updates the last used timestamp for an API key
func (s *Service) UpdateAPIKeyLastUsed(keyHash string) error {
	query := "UPDATE api_keys SET last_used_at = ? WHERE key_hash = ?"
	_, err := s.db.Exec(query, time.Now(), keyHash)
	return err
}

// CheckRateLimit checks and updates rate limiting for an identifier
func (s *Service) CheckRateLimit(identifier, endpoint string, limit int) (bool, error) {
	now := time.Now()
	windowStart := now.Truncate(time.Minute)

	// Try to get existing rate limit record
	var requestCount int
	err := s.db.QueryRow(
		"SELECT request_count FROM rate_limits WHERE identifier = ? AND endpoint = ? AND window_start = ?",
		identifier, endpoint, windowStart,
	).Scan(&requestCount)

	if err == sql.ErrNoRows {
		// No existing record, create new one
		_, err = s.db.Exec(
			"INSERT INTO rate_limits (id, identifier, endpoint, request_count, window_start) VALUES (?, ?, ?, 1, ?)",
			fmt.Sprintf("%s-%s-%d", identifier, endpoint, windowStart.Unix()),
			identifier, endpoint, windowStart,
		)
		return true, err
	} else if err != nil {
		return false, err
	}

	// Check if limit exceeded
	if requestCount >= limit {
		return false, nil
	}

	// Increment counter
	_, err = s.db.Exec(
		"UPDATE rate_limits SET request_count = request_count + 1 WHERE identifier = ? AND endpoint = ? AND window_start = ?",
		identifier, endpoint, windowStart,
	)

	return true, err
}

// IsWhitelisted checks if an IP is whitelisted for rate limiting
func (s *Service) IsWhitelisted(ip string) (bool, error) {
	query := `
		SELECT COUNT(*) FROM rate_limit_whitelist 
		WHERE is_active = true AND (ip_address = ? OR ? LIKE CONCAT(ip_range, '%'))
	`

	var count int
	err := s.db.QueryRow(query, ip, ip).Scan(&count)
	if err != nil {
		return false, err
	}

	return count > 0, nil
}

// UpdateSpeedTest updates an existing speed test record
func (s *Service) UpdateSpeedTest(test *models.SpeedTest) error {
	query := `
		UPDATE speed_tests SET
			download_speed_mbps = ?, upload_speed_mbps = ?, ping_latency_ms = ?, jitter_ms = ?,
			download_size_bytes = ?, upload_size_bytes = ?, test_duration_seconds = ?,
			isp = ?, country = ?, region = ?, city = ?, updated_at = ?
		WHERE id = ?
	`

	test.UpdatedAt = time.Now()
	_, err := s.db.Exec(query,
		test.DownloadSpeedMbps, test.UploadSpeedMbps, test.PingLatencyMs, test.JitterMs,
		test.DownloadSizeBytes, test.UploadSizeBytes, test.TestDurationSeconds,
		test.ISP, test.Country, test.Region, test.City, test.UpdatedAt, test.ID,
	)

	if err != nil {
		return fmt.Errorf("failed to update speed test: %v", err)
	}

	return nil
}

// CreateMetric creates a new metric record
func (s *Service) CreateMetric(metric interface{}) error {
	// Import the Metric type from metrics package
	// This is a simplified implementation that stores metrics as JSON
	query := `
		INSERT INTO metrics (id, timestamp, type, client_ip, user_agent, location, 
			latency_ms, jitter_ms, download_mbps, upload_mbps, test_duration_ms, 
			data_size_bytes, chunk_count, server_load, concurrent_users, 
			error_code, error_message, created_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
	`

	// This is a placeholder implementation
	// In a real scenario, you would properly map the metric struct fields
	_, err := s.db.Exec(query,
		"", time.Now(), "speed_test", "", "", "",
		0.0, 0.0, 0.0, 0.0, 0, 0, 0, 0.0, 0, "", "")

	if err != nil {
		return fmt.Errorf("failed to create metric: %v", err)
	}

	return nil
}

// GetMetrics retrieves metrics from the database
func (s *Service) GetMetrics(metricType string, startTime, endTime time.Time, limit int) ([]interface{}, error) {
	query := `
		SELECT id, timestamp, type, client_ip, user_agent, location,
			latency_ms, jitter_ms, download_mbps, upload_mbps, test_duration_ms,
			data_size_bytes, chunk_count, server_load, concurrent_users,
			error_code, error_message
		FROM metrics
		WHERE type = ? AND timestamp BETWEEN ? AND ?
		ORDER BY timestamp DESC
		LIMIT ?
	`

	rows, err := s.db.Query(query, metricType, startTime, endTime, limit)
	if err != nil {
		return nil, fmt.Errorf("failed to query metrics: %v", err)
	}
	defer rows.Close()

	var metrics []interface{}
	// This is a placeholder - you would populate actual metric structs here

	return metrics, nil
}

// GetServerStats returns aggregated server statistics
func (s *Service) GetServerStats(startTime, endTime time.Time) (*ServerStats, error) {
	query := `
		SELECT 
			COUNT(*) as total_tests,
			AVG(latency_ms) as avg_latency,
			AVG(download_mbps) as avg_download,
			AVG(upload_mbps) as avg_upload,
			MAX(concurrent_users) as peak_concurrent,
			(SELECT COUNT(*) FROM metrics WHERE type = 'error' AND timestamp BETWEEN ? AND ?) * 100.0 / COUNT(*) as error_rate
		FROM metrics
		WHERE type = 'speed_test' AND timestamp BETWEEN ? AND ?
	`

	var stats ServerStats
	err := s.db.QueryRow(query, startTime, endTime, startTime, endTime).Scan(
		&stats.TotalTests,
		&stats.AverageLatency,
		&stats.AverageDownload,
		&stats.AverageUpload,
		&stats.PeakConcurrent,
		&stats.ErrorRate,
	)

	if err != nil {
		return nil, fmt.Errorf("failed to get server stats: %v", err)
	}

	stats.Timestamp = time.Now().UTC()
	return &stats, nil
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
