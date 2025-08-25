-- Migration 004: Create metrics table for comprehensive performance monitoring

CREATE TABLE IF NOT EXISTS metrics (
    id VARCHAR(36) NOT NULL PRIMARY KEY,
    timestamp TIMESTAMP(3) NOT NULL,
    type ENUM('speed_test', 'error', 'system', 'performance') NOT NULL DEFAULT 'speed_test',
    client_ip VARCHAR(45) NOT NULL,
    user_agent TEXT,
    location JSON,
    
    -- Performance metrics
    latency_ms DECIMAL(10,2) DEFAULT NULL,
    jitter_ms DECIMAL(10,2) DEFAULT NULL,
    download_mbps DECIMAL(10,2) DEFAULT NULL,
    upload_mbps DECIMAL(10,2) DEFAULT NULL,
    test_duration_ms BIGINT DEFAULT NULL,
    data_size_bytes BIGINT DEFAULT NULL,
    chunk_count INT DEFAULT NULL,
    
    -- Server metrics
    server_load DECIMAL(5,2) DEFAULT NULL,
    concurrent_users INT DEFAULT NULL,
    
    -- Error tracking
    error_code VARCHAR(50) DEFAULT NULL,
    error_message TEXT DEFAULT NULL,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_metrics_timestamp (timestamp),
    INDEX idx_metrics_type (type),
    INDEX idx_metrics_client_ip (client_ip),
    INDEX idx_metrics_type_timestamp (type, timestamp)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Add indexes for performance
CREATE INDEX idx_metrics_performance ON metrics (type, timestamp, client_ip);
CREATE INDEX idx_metrics_stats ON metrics (type, timestamp, download_mbps, upload_mbps, latency_ms);
