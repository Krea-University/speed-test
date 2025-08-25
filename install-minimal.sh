#!/bin/bash

# Minimal TTY-Free Installation Script for Krea Speed Test Server
# This script provides the most minimal, TTY-free installation possible
# Usage: curl -fsSL <url>/install-minimal.sh | bash -s -- <domain> [email]

# FORCE COMPLETE NON-INTERACTIVE MODE
set -e
export DOCKER_NONINTERACTIVE=1
export DEBIAN_FRONTEND=noninteractive
export FORCE_NO_TTY=true
export BUILDKIT_PROGRESS=plain
export COMPOSE_INTERACTIVE_NO_CLI=1

# Close stdin immediately to prevent any TTY prompts
exec 0</dev/null

# Parse arguments
DOMAIN="$1"
EMAIL="${2:-admin@${DOMAIN}}"

if [ -z "$DOMAIN" ]; then
    echo "Error: Domain is required"
    echo "Usage: bash install-minimal.sh <domain> [email]"
    exit 1
fi

echo "Starting TTY-free installation for domain: $DOMAIN"
echo "Email: $EMAIL"

# Create temp directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

echo "Downloading deployment files..."

# Download only the essential files needed for deployment
curl -fsSL "https://raw.githubusercontent.com/Krea-University/speed-test/main/deploy-no-tty.sh" -o deploy-no-tty.sh

# Make executable
chmod +x deploy-no-tty.sh

echo "Starting deployment..."

# Execute with forced non-interactive mode
bash deploy-no-tty.sh "$DOMAIN" "$EMAIL"

echo "Installation completed successfully!"
echo "Cleaning up temporary files..."
cd /
rm -rf "$TEMP_DIR"

echo "Krea Speed Test Server is now running at: https://$DOMAIN"
