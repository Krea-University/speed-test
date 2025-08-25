#!/bin/bash

set -e  # Exit on any error

echo "🚀 Starting Speed Test Server Demo"
echo "=================================="

# Check for required tools
command -v curl >/dev/null 2>&1 || { echo "❌ curl is required but not installed. Aborting." >&2; exit 1; }

# Check if jq is available, if not use cat for basic output
if command -v jq >/dev/null 2>&1; then
    JSON_PRETTY="jq ."
else
    echo "⚠️  jq not found, output will not be prettified"
    JSON_PRETTY="cat"
fi

# Build the application using the new structure
echo "📦 Building application..."
go build -o speed-test ./cmd/speed-test

if [ $? -ne 0 ]; then
    echo "❌ Build failed"
    exit 1
fi

echo "✅ Build successful"

# Start the server in background
echo "🌐 Starting server on port 8080..."
./speed-test &
SERVER_PID=$!

# Wait for server to start
echo "⏳ Waiting for server to initialize..."
sleep 5

# Function to test if server is ready
wait_for_server() {
    local max_attempts=10
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s http://localhost:8080/healthz >/dev/null 2>&1; then
            echo "✅ Server is ready!"
            return 0
        fi
        echo "⏳ Attempt $attempt/$max_attempts - waiting for server..."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    echo "❌ Server failed to start properly"
    kill $SERVER_PID 2>/dev/null
    exit 1
}

wait_for_server

# Test endpoints
echo "🧪 Testing endpoints..."

echo "1. Health check:"
curl -s http://localhost:8080/healthz | $JSON_PRETTY

echo -e "\n2. Version:"
curl -s http://localhost:8080/version | $JSON_PRETTY

echo -e "\n3. Config:"
curl -s http://localhost:8080/config | $JSON_PRETTY

echo -e "\n4. Ping test:"
curl -s http://localhost:8080/ping | $JSON_PRETTY

echo -e "\n5. IP info (testing multiple providers):"
curl -s http://localhost:8080/ip | $JSON_PRETTY

echo -e "\n6. Small download test (1KB):"
curl -s "http://localhost:8080/download?size=1024" > /tmp/download_test.bin
echo "Downloaded $(wc -c < /tmp/download_test.bin) bytes"

echo -e "\n7. Upload test (sending 1KB):"
dd if=/dev/urandom bs=1024 count=1 2>/dev/null | curl -s -X POST --data-binary @- http://localhost:8080/upload | $JSON_PRETTY

# Clean up
echo -e "\n🧹 Cleaning up..."
kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null
rm -f /tmp/download_test.bin
rm -f speed-test

echo "✅ Demo completed successfully!"
echo "💡 You can now run 'make run' to start the server manually"
echo "📖 Check the README.md for more information about available endpoints and features"
