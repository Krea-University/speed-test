package handlers

import (
	"encoding/json"
	"log"
	"net/http"
	"time"
)

// AdminDashboard serves the admin dashboard page
func (h *Handlers) AdminDashboard(w http.ResponseWriter, r *http.Request) {
	if !h.isAdmin(r) {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	dashboardHTML := `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Speed Test Admin Dashboard</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 0; padding: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; border-radius: 10px; margin-bottom: 30px; }
        .stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .stat-card { background: white; padding: 20px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .stat-number { font-size: 2em; font-weight: bold; color: #667eea; }
        .stat-label { color: #666; margin-top: 5px; }
        .refresh-btn { background: #667eea; color: white; border: none; padding: 10px 20px; border-radius: 5px; cursor: pointer; margin-bottom: 20px; }
        .refresh-btn:hover { background: #5a67d8; }
        .tests-table { background: white; border-radius: 10px; overflow: hidden; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        table { width: 100%; border-collapse: collapse; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #eee; }
        th { background-color: #f8f9fa; font-weight: 600; }
        .status-active { color: #28a745; }
        .status-error { color: #dc3545; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Speed Test Admin Dashboard</h1>
            <p>Real-time monitoring and analytics for your speed test server</p>
        </div>
        <button class="refresh-btn" onclick="refreshData()">🔄 Refresh Data</button>
        <div class="stats-grid" id="stats-grid"></div>
        <div class="tests-table">
            <h3 style="padding: 20px 20px 0 20px; margin: 0;">Recent Speed Tests</h3>
            <table>
                <thead>
                    <tr><th>Time</th><th>Client IP</th><th>Location</th><th>Download (Mbps)</th><th>Upload (Mbps)</th><th>Latency (ms)</th><th>Status</th></tr>
                </thead>
                <tbody id="tests-tbody"></tbody>
            </table>
        </div>
    </div>
    <script>
        async function loadStats() {
            try {
                const response = await fetch('/admin/api/stats?admin_key=admin_secret_key_change_in_production');
                const stats = await response.json();
                document.getElementById('stats-grid').innerHTML = 
                    '<div class="stat-card"><div class="stat-number">' + (stats.total_tests || 0) + '</div><div class="stat-label">Total Tests</div></div>' +
                    '<div class="stat-card"><div class="stat-number">' + (stats.average_download || 0).toFixed(1) + '</div><div class="stat-label">Avg Download (Mbps)</div></div>' +
                    '<div class="stat-card"><div class="stat-number">' + (stats.average_upload || 0).toFixed(1) + '</div><div class="stat-label">Avg Upload (Mbps)</div></div>' +
                    '<div class="stat-card"><div class="stat-number">' + (stats.average_latency || 0).toFixed(0) + '</div><div class="stat-label">Avg Latency (ms)</div></div>';
            } catch (error) {
                console.error('Failed to load stats:', error);
            }
        }
        async function loadRecentTests() {
            try {
                const response = await fetch('/admin/api/recent-tests?admin_key=admin_secret_key_change_in_production');
                const tests = await response.json();
                const tbody = document.getElementById('tests-tbody');
                tbody.innerHTML = tests.map(test => 
                    '<tr><td>' + new Date(test.timestamp).toLocaleString() + '</td>' +
                    '<td>' + test.client_ip + '</td>' +
                    '<td>' + (test.location || 'Unknown') + '</td>' +
                    '<td>' + (test.download_mbps || 0).toFixed(1) + '</td>' +
                    '<td>' + (test.upload_mbps || 0).toFixed(1) + '</td>' +
                    '<td>' + (test.latency_ms || 0).toFixed(0) + '</td>' +
                    '<td class="' + (test.error_code ? 'status-error' : 'status-active') + '">' + (test.error_code ? 'Error' : 'Success') + '</td></tr>'
                ).join('');
            } catch (error) {
                console.error('Failed to load recent tests:', error);
            }
        }
        function refreshData() { loadStats(); loadRecentTests(); }
        document.addEventListener('DOMContentLoaded', refreshData);
        setInterval(refreshData, 30000);
    </script>
</body>
</html>`

	w.Header().Set("Content-Type", "text/html")
	w.Write([]byte(dashboardHTML))
}

// AdminStats returns server statistics as JSON
func (h *Handlers) AdminStats(w http.ResponseWriter, r *http.Request) {
	if !h.isAdmin(r) {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	var stats interface{}
	if h.db != nil {
		endTime := time.Now().UTC()
		startTime := endTime.Add(-24 * time.Hour)
		dbStats, err := h.db.GetServerStats(startTime, endTime)
		if err != nil {
			log.Printf("Failed to get server stats: %v", err)
			stats = h.getMockStats()
		} else {
			stats = dbStats
		}
	} else {
		stats = h.getMockStats()
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(stats)
}

// AdminRecentTests returns recent test results as JSON
func (h *Handlers) AdminRecentTests(w http.ResponseWriter, r *http.Request) {
	if !h.isAdmin(r) {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	var tests interface{}
	if h.db != nil {
		endTime := time.Now().UTC()
		startTime := endTime.Add(-24 * time.Hour)
		dbTests, err := h.db.GetMetrics("speed_test", startTime, endTime, 50)
		if err != nil {
			log.Printf("Failed to get recent tests: %v", err)
			tests = h.getMockTests()
		} else {
			tests = dbTests
		}
	} else {
		tests = h.getMockTests()
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(tests)
}

// AdminSystemInfo returns system information
func (h *Handlers) AdminSystemInfo(w http.ResponseWriter, r *http.Request) {
	if !h.isAdmin(r) {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	systemInfo := map[string]interface{}{
		"server_time":  time.Now().UTC(),
		"uptime_hours": 24.5,
		"active_tests": h.rateLimiter.GetActiveConnections(),
		"memory_usage": map[string]interface{}{"used_mb": 256, "total_mb": 512, "usage_percent": 50.0},
		"version":      "1.0.0",
		"rate_limiter": h.rateLimiter.GetStats(),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(systemInfo)
}

// isAdmin checks if the request has admin privileges
func (h *Handlers) isAdmin(r *http.Request) bool {
	apiKey := r.Header.Get("X-Admin-API-Key")
	if apiKey == "" {
		apiKey = r.URL.Query().Get("admin_key")
	}
	return apiKey == "admin_secret_key_change_in_production"
}

// getMockStats returns mock statistics when database is not available
func (h *Handlers) getMockStats() map[string]interface{} {
	return map[string]interface{}{
		"total_tests":      1250,
		"average_download": 87.5,
		"average_upload":   42.3,
		"average_latency":  23.4,
		"peak_concurrent":  15,
		"error_rate":       2.1,
		"timestamp":        time.Now().UTC(),
	}
}

// getMockTests returns mock test data when database is not available
func (h *Handlers) getMockTests() []map[string]interface{} {
	now := time.Now().UTC()
	return []map[string]interface{}{
		{
			"timestamp":     now.Add(-5 * time.Minute),
			"client_ip":     "192.168.1.100",
			"location":      "San Francisco, CA",
			"download_mbps": 95.2,
			"upload_mbps":   45.8,
			"latency_ms":    18.5,
			"error_code":    "",
		},
		{
			"timestamp":     now.Add(-12 * time.Minute),
			"client_ip":     "10.0.0.50",
			"location":      "New York, NY",
			"download_mbps": 78.4,
			"upload_mbps":   38.9,
			"latency_ms":    32.1,
			"error_code":    "",
		},
	}
}
