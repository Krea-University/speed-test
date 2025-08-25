#!/bin/bash

# Test TTY detection
echo "Testing TTY detection..."

# Docker Compose wrapper for non-interactive environments
docker_exec() {
    if [ -t 0 ]; then
        echo "TTY detected - would run: docker-compose exec $@"
    else
        echo "No TTY detected - would run: docker-compose exec -T $@"
    fi
}

echo "=== Testing in current environment ==="
docker_exec mysql sh -c "echo 'test'"

echo ""
echo "=== Testing with input redirection ==="
echo "test" | docker_exec mysql sh -c "echo 'test'"

echo ""
echo "=== Testing with background execution ==="
(docker_exec nginx nginx -s reload) &
wait

echo ""
echo "=== Manual TTY check ==="
if [ -t 0 ]; then
    echo "stdin is a terminal"
else
    echo "stdin is not a terminal"
fi

if [ -t 1 ]; then
    echo "stdout is a terminal"
else
    echo "stdout is not a terminal"
fi
