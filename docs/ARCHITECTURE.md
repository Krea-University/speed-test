# Speed Test Server - Architecture Overview

## 🏗️ Project Structure

This document provides a comprehensive overview of the Speed Test Server's architecture, designed following Go best practices and clean architecture principles.

## 📁 Directory Structure

```
speed-test/
├── cmd/                    # Application entry points
│   └── speed-test/        # Main application
│       └── main.go        # Entry point with minimal logic
│
├── internal/              # Private application packages
│   ├── config/           # Configuration constants and settings
│   │   └── config.go     # Application constants and defaults
│   │
│   ├── handlers/         # HTTP request handlers
│   │   ├── handlers.go   # All HTTP endpoint handlers
│   │   └── handlers_test.go # Comprehensive handler tests
│   │
│   ├── ipservice/        # IP geolocation service layer
│   │   └── providers.go  # Multiple provider implementations with fallback
│   │
│   ├── middleware/       # HTTP middleware components
│   │   └── middleware.go # CORS, logging, security middleware
│   │
│   ├── server/          # Server setup and configuration
│   │   └── server.go    # HTTP server with graceful shutdown
│   │
│   └── types/           # Shared data structures
│       └── types.go     # Request/response types and structs
│
├── client/              # Example client implementation
│   └── main.go         # Test client for speed testing
│
├── docs/               # Documentation
│   └── API_PROVIDERS.md # IP provider documentation
│
├── bin/                # Build output directory
├── tmp/                # Temporary files (Air live reload)
│
├── .air.toml          # Air configuration for development
├── .env.example       # Environment variables template
├── .gitignore         # Git ignore rules
├── Dockerfile         # Multi-stage Docker build
├── Makefile          # Build automation and common tasks
├── demo.sh           # Demonstration script
├── go.mod            # Go module definition
├── go.sum            # Dependency checksums
└── README.md         # Main documentation
```

## 🎯 Design Principles

### 1. Clean Architecture
- **Separation of Concerns**: Each package has a single responsibility
- **Dependency Inversion**: Internal packages depend on abstractions, not implementations
- **Testability**: All components are easily testable in isolation

### 2. Go Best Practices
- **Package Structure**: Following standard Go project layout
- **Internal Packages**: Preventing external import of internal logic
- **Error Handling**: Proper error propagation and logging
- **Context Usage**: Proper context handling for cancellation and timeouts

### 3. Reliability
- **Graceful Shutdown**: Proper signal handling and connection draining
- **Health Checks**: Built-in health monitoring endpoints
- **Provider Fallback**: Multiple IP providers with automatic failover
- **Error Recovery**: Graceful degradation when services fail

## 🔧 Component Details

### Config Package
- **Purpose**: Centralized configuration constants
- **Benefits**: Single source of truth, easy to modify defaults
- **Contents**: Buffer sizes, timeouts, default values

### Handlers Package
- **Purpose**: HTTP request/response handling
- **Benefits**: Clean separation of HTTP logic from business logic
- **Features**: Comprehensive error handling, proper HTTP status codes

### IP Service Package
- **Purpose**: IP geolocation with multiple providers
- **Benefits**: High availability through provider fallback
- **Providers**: ipinfo.io → ip-api.com → freeipapi.com

### Middleware Package
- **Purpose**: Cross-cutting concerns for HTTP requests
- **Features**: CORS, logging, security headers, request timing
- **Benefits**: Consistent behavior across all endpoints

### Server Package
- **Purpose**: HTTP server lifecycle management
- **Features**: Graceful shutdown, signal handling, route configuration
- **Benefits**: Proper resource cleanup and production-ready server

### Types Package
- **Purpose**: Shared data structures
- **Benefits**: Type safety, consistent API responses
- **Contents**: Request/response structs, configuration types

## 🚀 Deployment Patterns

### Development
```bash
make dev    # Live reload with Air
make test   # Comprehensive testing
make lint   # Code quality checks
```

### Production
```bash
make build       # Optimized binary
make docker-build # Container image
```

### Multi-Platform
```bash
make build-all   # Linux, macOS, Windows binaries
```

## 🔒 Security Features

- **CORS Configuration**: Proper cross-origin request handling
- **Security Headers**: XSS protection, clickjacking prevention
- **Input Validation**: Size limits, parameter validation
- **Non-Root Container**: Docker runs as non-privileged user

## 📊 Monitoring & Observability

- **Health Checks**: `/healthz` endpoint for monitoring
- **Request Logging**: Comprehensive HTTP request logging
- **Error Handling**: Proper error responses and logging
- **Graceful Degradation**: Service continues even if providers fail

## 🧪 Testing Strategy

- **Unit Tests**: All handlers and core logic tested
- **Integration Tests**: End-to-end API testing
- **Provider Tests**: IP service provider testing
- **Coverage Reports**: Code coverage tracking with `make test-coverage`

This architecture ensures the Speed Test Server is maintainable, scalable, and production-ready while following Go community standards and best practices.
