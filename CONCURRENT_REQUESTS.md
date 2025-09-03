# Concurrent Request Limiting

This document explains how to configure and use the concurrent request limiting feature in the Krea Speed Test Server.

## Overview

The server includes a configurable concurrent request limiter that prevents server overload by limiting the number of simultaneous requests being processed. This is especially important for speed test servers that handle resource-intensive operations like large file uploads and downloads.

## Configuration

### Default Settings
- **Default Maximum Concurrent Requests**: 8
- **Behavior when limit exceeded**: Returns HTTP 503 (Service Unavailable) with a `Retry-After: 1` header

### Environment Variable Configuration

You can configure the maximum number of concurrent requests using the `MAX_CONCURRENT_REQUESTS` environment variable:

```bash
# Set maximum concurrent requests to 16
export MAX_CONCURRENT_REQUESTS=16

# Start the server
go run cmd/speed-test-server/main.go
```

### Examples

#### Production Server (Higher Capacity)
```bash
export MAX_CONCURRENT_REQUESTS=20
go run cmd/speed-test-server/main.go
```

#### Development/Testing (Lower Capacity)
```bash
export MAX_CONCURRENT_REQUESTS=4
go run cmd/speed-test-server/main.go
```

#### Using Docker
```bash
docker run -e MAX_CONCURRENT_REQUESTS=12 -p 8080:8080 krea-speed-test-server
```

## How It Works

1. **Request Arrival**: When a request arrives, the middleware checks if there's an available slot
2. **Slot Available**: If a slot is available, the request proceeds normally
3. **No Slots Available**: If all slots are occupied, the server returns:
   - HTTP Status: `503 Service Unavailable`
   - Header: `Retry-After: 1`
   - Body: "Server is busy. Please try again later."
4. **Slot Release**: When a request completes, its slot is automatically released for the next waiting request

## Monitoring

The server logs concurrent request limiting events:

```
2025/09/02 23:15:30 Request rejected due to concurrent limit (8 active requests)
```

You can monitor this in your application logs to understand traffic patterns and adjust the limit accordingly.

## Testing the Feature

### Load Testing Script

```bash
#!/bin/bash
# Test concurrent request limiting

echo "Testing with 10 concurrent requests (should trigger limiting with default setting of 8)"

for i in {1..10}; do
  curl -s -o /dev/null -w "Request $i: %{http_code}\n" http://localhost:8080/ping &
done

wait
echo "All requests completed"
```

### Expected Output
With default settings (8 concurrent requests), you should see:
- 8 requests returning `200 OK`
- 2 requests returning `503 Service Unavailable`

## Best Practices

1. **Sizing**: Set the limit based on your server's resources and expected load
   - CPU-bound operations: Lower limit (4-8)
   - I/O-bound operations: Higher limit (16-32)
   - Memory-intensive operations: Very low limit (2-4)

2. **Monitoring**: Monitor your logs for rejected requests and adjust accordingly

3. **Load Balancing**: For high-traffic scenarios, consider using multiple server instances behind a load balancer

4. **Client Retry Logic**: Implement exponential backoff in clients when receiving 503 responses

## Performance Impact

The concurrent request limiter has minimal overhead:
- **Memory**: Negligible (small channel buffer)
- **CPU**: Very low (simple channel operations)
- **Latency**: < 1ms additional latency per request

## Troubleshooting

### High Number of 503 Responses
- Increase `MAX_CONCURRENT_REQUESTS`
- Check server resources (CPU, memory, network)
- Consider scaling horizontally

### Server Still Overloaded
- Decrease `MAX_CONCURRENT_REQUESTS`
- Optimize request handlers
- Add caching where appropriate

### Configuration Not Taking Effect
- Verify environment variable is set: `echo $MAX_CONCURRENT_REQUESTS`
- Restart the server after changing the environment variable
- Check server startup logs for the configured limit
