#!/bin/bash

# Test the updated install.sh argument parsing
echo "🧪 Testing updated install.sh argument parsing..."

# Simulate the argument parsing logic
FLAGS=()
POSITIONAL=()
FORCE_NO_TTY=false

# Test arguments: --no-tty --debug-tty api-speedtest.krea.edu.in erpadmin@krea.edu.in
test_args=("--no-tty" "--debug-tty" "api-speedtest.krea.edu.in" "erpadmin@krea.edu.in")
set -- "${test_args[@]}"

while [[ $# -gt 0 ]]; do
    case $1 in
        --no-tty)
            FORCE_NO_TTY=true
            FLAGS+=("$1")
            shift
            ;;
        --debug-tty)
            FLAGS+=("$1")
            shift
            ;;
        *)
            POSITIONAL+=("$1")
            shift
            ;;
    esac
done

# Configuration from positional arguments
DOMAIN="${POSITIONAL[0]}"
EMAIL="${POSITIONAL[1]:-admin@${DOMAIN}}"

echo "✅ Parsing results:"
echo "   FLAGS: ${FLAGS[*]}"
echo "   POSITIONAL: ${POSITIONAL[*]}"
echo "   DOMAIN: $DOMAIN"
echo "   EMAIL: $EMAIL"
echo "   FORCE_NO_TTY: $FORCE_NO_TTY"

echo ""
echo "🚀 Deploy command would be:"
echo "   ./deploy.sh ${FLAGS[*]} $DOMAIN $EMAIL"

echo ""
if [[ -n "$DOMAIN" ]]; then
    echo "✅ Argument parsing working correctly!"
else
    echo "❌ Argument parsing failed - missing domain"
fi
