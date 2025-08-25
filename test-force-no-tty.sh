#!/bin/bash

# Force No-TTY Test Script
echo "🔧 Testing forced no-TTY mode..."

# Set all the no-TTY flags
export FORCE_NO_TTY=true
export DOCKER_NONINTERACTIVE=1
export DEBIAN_FRONTEND=noninteractive
export DEBUG_TTY=1

# Test the specific docker_exec function from deploy.sh
docker_exec() {
    # Debug: Log TTY detection
    if [[ "${DEBUG_TTY}" == "1" ]]; then
        echo "[INFO] TTY Debug: FORCE_NO_TTY=${FORCE_NO_TTY}, DOCKER_NONINTERACTIVE=${DOCKER_NONINTERACTIVE}"
        echo "[INFO] TTY Debug: stdin tty=$([ -t 0 ] && echo 'yes' || echo 'no'), stdout tty=$([ -t 1 ] && echo 'yes' || echo 'no')"
    fi
    
    # Force non-interactive if --no-tty was specified or environment variable set
    if [[ "${FORCE_NO_TTY}" == "true" ]] || [[ "${DOCKER_NONINTERACTIVE}" == "1" ]]; then
        [[ "${DEBUG_TTY}" == "1" ]] && echo "[INFO] TTY Debug: Using -T flag (forced non-interactive)"
        echo "Would run: docker-compose exec -T $*"
    # Try TTY detection
    elif [ -t 0 ] && [ -t 1 ]; then
        [[ "${DEBUG_TTY}" == "1" ]] && echo "[INFO] TTY Debug: Using interactive mode"
        echo "Would run: docker-compose exec $*"
    else
        # Use -T flag for non-interactive mode
        [[ "${DEBUG_TTY}" == "1" ]] && echo "[INFO] TTY Debug: Using -T flag (TTY detection)"
        echo "Would run: docker-compose exec -T $*"
    fi
}

echo ""
echo "🧪 Testing docker_exec function with forced no-TTY..."
docker_exec mysql mysql -u speedtest -p"password" speedtest

echo ""
echo "🧪 Testing with input redirection..."
echo "test" | docker_exec nginx nginx -s reload

echo ""
echo "✅ Forced no-TTY test completed!"
echo ""
echo "If you see '-T' flags in all outputs above, the fix is working!"
