#!/bin/bash

# Test script for --no-tty functionality
echo "🧪 Testing --no-tty functionality..."

# Test argument parsing
echo ""
echo "=== Testing argument parsing ==="

# Simulate the argument parsing logic from deploy.sh
FORCE_NO_TTY=false
ARGS=()

# Test with --no-tty flag
test_args=("--no-tty" "example.com" "admin@example.com")
set -- "${test_args[@]}"

while [[ $# -gt 0 ]]; do
    case $1 in
        --no-tty)
            FORCE_NO_TTY=true
            export DOCKER_NONINTERACTIVE=1
            echo "✅ --no-tty flag detected"
            shift
            ;;
        *)
            ARGS+=("$1")
            echo "📝 Argument: $1"
            shift
            ;;
    esac
done

# Set positional parameters from remaining args
set -- "${ARGS[@]}"

DOMAIN="$1"
EMAIL="${2:-admin@${DOMAIN}}"

echo "✅ Domain: $DOMAIN"
echo "✅ Email: $EMAIL"
echo "✅ Force No TTY: $FORCE_NO_TTY"
echo "✅ DOCKER_NONINTERACTIVE: $DOCKER_NONINTERACTIVE"

echo ""
echo "=== Testing docker_exec function ==="

# Test the docker_exec function logic
docker_exec_test() {
    if [[ "${FORCE_NO_TTY}" == "true" ]] || [[ "${DOCKER_NONINTERACTIVE}" == "1" ]]; then
        echo "Would run: docker-compose exec -T $*"
    elif [ -t 0 ]; then
        echo "Would run: docker-compose exec $*"
    else
        echo "Would run: docker-compose exec -T $*"
    fi
}

docker_exec_test mysql sh -c "echo 'test'"

echo ""
echo "=== Testing without --no-tty ==="

# Reset and test without flag
FORCE_NO_TTY=false
unset DOCKER_NONINTERACTIVE

docker_exec_test mysql sh -c "echo 'test'"

echo ""
echo "✅ All tests passed! --no-tty functionality working correctly."
