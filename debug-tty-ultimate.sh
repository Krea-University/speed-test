#!/bin/bash

# Ultimate TTY Debug Script for Deploy Issues
echo "🔍 Ultimate TTY Debug Script"
echo "=============================="

# Test all environment combinations
test_scenarios=(
    "normal"
    "force_no_tty"
    "env_var"
    "both"
)

for scenario in "${test_scenarios[@]}"; do
    echo ""
    echo "🧪 Testing scenario: $scenario"
    echo "--------------------------------"
    
    # Reset environment
    unset FORCE_NO_TTY
    unset DOCKER_NONINTERACTIVE
    unset DEBUG_TTY
    
    case $scenario in
        "normal")
            echo "   Using: Default settings"
            ;;
        "force_no_tty")
            export FORCE_NO_TTY=true
            echo "   Using: FORCE_NO_TTY=true"
            ;;
        "env_var")
            export DOCKER_NONINTERACTIVE=1
            echo "   Using: DOCKER_NONINTERACTIVE=1"
            ;;
        "both")
            export FORCE_NO_TTY=true
            export DOCKER_NONINTERACTIVE=1
            echo "   Using: Both flags"
            ;;
    esac
    
    # Test docker_exec function
    docker_exec_test() {
        if [[ "${FORCE_NO_TTY}" == "true" ]] || [[ "${DOCKER_NONINTERACTIVE}" == "1" ]]; then
            echo "     Result: docker-compose exec -T $*"
        elif [ -t 0 ] && [ -t 1 ]; then
            echo "     Result: docker-compose exec $*"
        else
            echo "     Result: docker-compose exec -T $*"
        fi
    }
    
    # Test various commands
    docker_exec_test mysql mysql -u speedtest -p"password" speedtest
    docker_exec_test nginx nginx -s reload
done

echo ""
echo "🚨 RECOMMENDATION:"
echo "================================"
echo "Based on your error, try running:"
echo ""
echo "1. With debug enabled:"
echo "   sudo ./deploy.sh --no-tty --debug-tty yourdomain.com"
echo ""
echo "2. With environment variable:"
echo "   sudo DOCKER_NONINTERACTIVE=1 ./deploy.sh yourdomain.com"
echo ""
echo "3. With the safe wrapper:"
echo "   sudo ./deploy-no-tty.sh yourdomain.com"
echo ""
echo "The debug output will show exactly where the TTY error occurs!"
