package ratelimit

import (
	"sync"
	"time"
)

// ClientLimiter manages rate limiting per client
type ClientLimiter struct {
	mu              sync.RWMutex
	clients         map[string]*ClientInfo
	globalLimit     int
	perClientLimit  int
	timeWindow      time.Duration
	whitelist       map[string]bool
	cleanupInterval time.Duration
}

// ClientInfo tracks information about a specific client
type ClientInfo struct {
	IP            string
	Requests      []time.Time
	ActiveTests   int
	TotalRequests int64
	LastSeen      time.Time
	IsBlocked     bool
	BlockedUntil  time.Time
}

// NewClientLimiter creates a new per-client rate limiter
func NewClientLimiter(globalLimit, perClientLimit int, timeWindow time.Duration) *ClientLimiter {
	limiter := &ClientLimiter{
		clients:         make(map[string]*ClientInfo),
		globalLimit:     globalLimit,
		perClientLimit:  perClientLimit,
		timeWindow:      timeWindow,
		whitelist:       make(map[string]bool),
		cleanupInterval: 10 * time.Minute,
	}

	// Start cleanup goroutine
	go limiter.cleanupExpiredEntries()

	return limiter
}

// IsAllowed checks if a request from the given IP is allowed
func (cl *ClientLimiter) IsAllowed(ip string) bool {
	cl.mu.Lock()
	defer cl.mu.Unlock()

	now := time.Now()

	// Check if IP is whitelisted
	if cl.whitelist[ip] {
		cl.updateClientInfo(ip, now)
		return true
	}

	// Get or create client info
	client := cl.getOrCreateClient(ip, now)

	// Check if client is currently blocked
	if client.IsBlocked && now.Before(client.BlockedUntil) {
		return false
	}

	// Remove expired requests
	validRequests := make([]time.Time, 0)
	cutoff := now.Add(-cl.timeWindow)
	for _, reqTime := range client.Requests {
		if reqTime.After(cutoff) {
			validRequests = append(validRequests, reqTime)
		}
	}
	client.Requests = validRequests

	// Check per-client limit
	if len(client.Requests) >= cl.perClientLimit {
		// Block client for a period
		client.IsBlocked = true
		client.BlockedUntil = now.Add(5 * time.Minute)
		return false
	}

	// Check global limit
	totalActiveRequests := cl.getTotalActiveRequests(now)
	if totalActiveRequests >= cl.globalLimit {
		return false
	}

	// Allow request and record it
	client.Requests = append(client.Requests, now)
	client.TotalRequests++
	client.LastSeen = now
	client.IsBlocked = false

	return true
}

// AddToWhitelist adds an IP to the whitelist
func (cl *ClientLimiter) AddToWhitelist(ip string) {
	cl.mu.Lock()
	defer cl.mu.Unlock()
	cl.whitelist[ip] = true
}

// RemoveFromWhitelist removes an IP from the whitelist
func (cl *ClientLimiter) RemoveFromWhitelist(ip string) {
	cl.mu.Lock()
	defer cl.mu.Unlock()
	delete(cl.whitelist, ip)
}

// IncrementActiveTests increments the active test count for a client
func (cl *ClientLimiter) IncrementActiveTests(ip string) {
	cl.mu.Lock()
	defer cl.mu.Unlock()

	client := cl.getOrCreateClient(ip, time.Now())
	client.ActiveTests++
}

// DecrementActiveTests decrements the active test count for a client
func (cl *ClientLimiter) DecrementActiveTests(ip string) {
	cl.mu.Lock()
	defer cl.mu.Unlock()

	if client, exists := cl.clients[ip]; exists {
		if client.ActiveTests > 0 {
			client.ActiveTests--
		}
	}
}

// GetActiveConnections returns the total number of active connections
func (cl *ClientLimiter) GetActiveConnections() int {
	cl.mu.RLock()
	defer cl.mu.RUnlock()

	total := 0
	for _, client := range cl.clients {
		total += client.ActiveTests
	}
	return total
}

// GetClientStats returns statistics for all clients
func (cl *ClientLimiter) GetClientStats() map[string]*ClientInfo {
	cl.mu.RLock()
	defer cl.mu.RUnlock()

	stats := make(map[string]*ClientInfo)
	for ip, client := range cl.clients {
		stats[ip] = &ClientInfo{
			IP:            client.IP,
			Requests:      make([]time.Time, len(client.Requests)),
			ActiveTests:   client.ActiveTests,
			TotalRequests: client.TotalRequests,
			LastSeen:      client.LastSeen,
			IsBlocked:     client.IsBlocked,
			BlockedUntil:  client.BlockedUntil,
		}
		copy(stats[ip].Requests, client.Requests)
	}
	return stats
}

// UpdateLimits updates the rate limiting configuration
func (cl *ClientLimiter) UpdateLimits(globalLimit, perClientLimit int, timeWindow time.Duration) {
	cl.mu.Lock()
	defer cl.mu.Unlock()

	cl.globalLimit = globalLimit
	cl.perClientLimit = perClientLimit
	cl.timeWindow = timeWindow
}

// getOrCreateClient gets existing client or creates a new one
func (cl *ClientLimiter) getOrCreateClient(ip string, now time.Time) *ClientInfo {
	client, exists := cl.clients[ip]
	if !exists {
		client = &ClientInfo{
			IP:            ip,
			Requests:      make([]time.Time, 0),
			ActiveTests:   0,
			TotalRequests: 0,
			LastSeen:      now,
			IsBlocked:     false,
		}
		cl.clients[ip] = client
	}
	return client
}

// updateClientInfo updates the last seen time for a client
func (cl *ClientLimiter) updateClientInfo(ip string, now time.Time) {
	client := cl.getOrCreateClient(ip, now)
	client.LastSeen = now
	client.TotalRequests++
}

// getTotalActiveRequests returns the total number of active requests across all clients
func (cl *ClientLimiter) getTotalActiveRequests(now time.Time) int {
	total := 0
	cutoff := now.Add(-cl.timeWindow)

	for _, client := range cl.clients {
		for _, reqTime := range client.Requests {
			if reqTime.After(cutoff) {
				total++
			}
		}
	}
	return total
}

// cleanupExpiredEntries removes old client entries periodically
func (cl *ClientLimiter) cleanupExpiredEntries() {
	ticker := time.NewTicker(cl.cleanupInterval)
	defer ticker.Stop()

	for range ticker.C {
		cl.mu.Lock()
		now := time.Now()
		cutoff := now.Add(-24 * time.Hour) // Remove clients not seen for 24 hours

		for ip, client := range cl.clients {
			if client.LastSeen.Before(cutoff) && client.ActiveTests == 0 {
				delete(cl.clients, ip)
			}
		}
		cl.mu.Unlock()
	}
}

// GetStats returns overall rate limiter statistics
func (cl *ClientLimiter) GetStats() map[string]interface{} {
	cl.mu.RLock()
	defer cl.mu.RUnlock()

	activeClients := 0
	blockedClients := 0
	totalActiveTests := 0
	now := time.Now()

	for _, client := range cl.clients {
		if client.LastSeen.After(now.Add(-5 * time.Minute)) {
			activeClients++
		}
		if client.IsBlocked && now.Before(client.BlockedUntil) {
			blockedClients++
		}
		totalActiveTests += client.ActiveTests
	}

	return map[string]interface{}{
		"total_clients":       len(cl.clients),
		"active_clients":      activeClients,
		"blocked_clients":     blockedClients,
		"total_active_tests":  totalActiveTests,
		"whitelist_count":     len(cl.whitelist),
		"global_limit":        cl.globalLimit,
		"per_client_limit":    cl.perClientLimit,
		"time_window_seconds": int(cl.timeWindow.Seconds()),
	}
}
