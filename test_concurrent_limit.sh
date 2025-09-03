#!/bin/bash

echo "Testing concurrent request limiting..."
echo "Sending 8 concurrent requests to test the limit of 4"

# Function to make a request and show the response code
make_request() {
    local id=$1
    response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/ping)
    echo "Request $id: HTTP $response"
}

# Start 8 concurrent requests
for i in {1..8}; do
    make_request $i &
done

# Wait for all requests to complete
wait

echo "All requests completed"
echo ""
echo "Expected behavior:"
echo "- With limit of 4 concurrent requests"
echo "- 4 requests should return 200 (success)"
echo "- 4 requests should return 503 (service unavailable)"
