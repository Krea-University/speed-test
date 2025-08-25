#!/bin/bash

set -e

echo "🚀 Setting up Krea Speed Test Development Environment"
echo "===================================================="

# Check for required tools
echo "📋 Checking prerequisites..."
command -v docker >/dev/null 2>&1 || { echo "❌ Docker is required but not installed. Aborting." >&2; exit 1; }
command -v docker-compose >/dev/null 2>&1 || { echo "❌ Docker Compose is required but not installed. Aborting." >&2; exit 1; }
command -v go >/dev/null 2>&1 || { echo "❌ Go is required but not installed. Aborting." >&2; exit 1; }

echo "✅ Prerequisites check passed"

# Download Go dependencies
echo "📦 Downloading Go dependencies..."
go mod tidy

# Build the application
echo "🔨 Building application..."
make build

# Setup environment file
if [ ! -f .env ]; then
    echo "📝 Creating environment file..."
    cp .env.example .env
    echo "✏️  Please edit .env file with your configuration"
fi

# Start database with Docker Compose
echo "🐳 Starting MySQL database..."
docker-compose up -d mysql

# Wait for MySQL to be ready
echo "⏳ Waiting for MySQL to be ready..."
sleep 15

# Check if MySQL is ready
echo "🔍 Testing database connection..."
docker-compose exec -T mysql mysql -uroot -ppassword -e "SELECT 1;" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Database is ready"
else
    echo "❌ Database is not ready. Please check Docker logs."
    exit 1
fi

# Run database migrations
echo "📊 Setting up database schema..."
docker-compose exec -T mysql mysql -uspeedtest -pspeedtest speedtest < migrations/001_create_tables.up.sql

echo "🎉 Development environment setup complete!"
echo ""
echo "📝 Next steps:"
echo "   1. Edit .env file with your configuration"
echo "   2. Run 'make run' to start the server"
echo "   3. Visit http://localhost:8080/swagger/ for API documentation"
echo "   4. Visit http://localhost:8081 for database management (Adminer)"
echo ""
echo "🔑 API Testing:"
echo "   Use X-API-Key: demo-api-key-2025 for testing API endpoints"
echo ""
echo "🧪 Test endpoints:"
echo "   curl http://localhost:8080/ping"
echo "   curl http://localhost:8080/ip"
echo "   curl -H 'X-API-Key: demo-api-key-2025' http://localhost:8080/api/tests"
