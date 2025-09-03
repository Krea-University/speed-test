#!/bin/bash

echo "Testing concurrent request limiting with 6 requests against limit of 4..."

# Start a few slow requests to occupy slots
for i in {1..6}; do
    echo "Starting request $i"
    (sleep 2; curl -s -o /dev/null -w "Request $i: %{http_code}\n" http://localhost:8080/download?size=10000000) &
done

sleep 1

# Now send quick requests to test the limit
echo "Sending quick ping requests to test limit..."
for i in {7..10}; do
    curl -s -o /dev/null -w "Quick request $i: %{http_code}\n" http://localhost:8080/ping &
done

wait
echo "All requests completed"
