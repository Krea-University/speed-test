.PHONY: build run clean test docker-build docker-run fmt lint deps dev dev-tools setup migrate

# Build the application
build:
	go build -o bin/speed-test ./cmd/speed-test

# Run the application
run:
	go run ./cmd/speed-test

# Clean build artifacts
clean:
	rm -rf bin/
	docker-compose down -v

# Run tests
test:
	go test -v ./...

# Run tests with coverage
test-coverage:
	go test -v -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html

# Format code
fmt:
	go fmt ./...

# Lint code
lint:
	golangci-lint run

# Install dependencies
deps:
	go mod download
	go mod tidy

# Setup development environment
setup:
	./setup-dev.sh

# Database migrations
migrate-up:
	docker-compose exec mysql mysql -uspeedtest -pspeedtest speedtest < migrations/001_create_tables.up.sql

migrate-down:
	docker-compose exec mysql mysql -uspeedtest -pspeedtest speedtest < migrations/001_create_tables.down.sql

# Docker operations
docker-build:
	docker build -t speed-test .

docker-run:
	docker run -p 8080:8080 --name speed-test-container speed-test

docker-compose-up:
	docker-compose up -d

docker-compose-down:
	docker-compose down

docker-compose-logs:
	docker-compose logs -f

# Development server with auto-reload (requires air)
dev:
	air -c .air.toml

# Install development tools
dev-tools:
	go install github.com/cosmtrek/air@latest
	go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	go install github.com/swaggo/swag/cmd/swag@latest

# Generate Swagger documentation
swagger:
	swag init -g cmd/speed-test/main.go -o docs

# Run benchmarks
bench:
	go test -bench=. -benchmem ./...

# Generate documentation
docs:
	godoc -http=:6060

# Build for multiple platforms
build-all:
	GOOS=linux GOARCH=amd64 go build -o bin/speed-test-linux-amd64 ./cmd/speed-test
	GOOS=darwin GOARCH=amd64 go build -o bin/speed-test-darwin-amd64 ./cmd/speed-test
	GOOS=windows GOARCH=amd64 go build -o bin/speed-test-windows-amd64.exe ./cmd/speed-test

# API testing helpers
test-api:
	@echo "Testing API endpoints..."
	@curl -s http://localhost:8080/ping | jq .
	@echo "\nTesting authenticated endpoint..."
	@curl -s -H "X-API-Key: demo-api-key-2025" http://localhost:8080/api/tests | jq .

# Load test
load-test:
	@echo "Running load test..."
	@for i in {1..10}; do curl -s http://localhost:8080/ping > /dev/null & done
	@wait
	@echo "Load test completed"
