# Krea Speed Test Server

Krea Speed Test Server is a lightweight Golang service for self-hosted internet speed testing. It provides endpoints to measure latency, jitter, download, and upload speeds, as well as IP lookup with optional geolocation. It is designed to mimic features of popular tools like Ookla, but fully under your control.

---

# Krea Speed Test Server

Krea Speed Test Server is a lightweight, professionally-architected Golang service for self-hosted internet speed testing. It provides endpoints to measure latency, jitter, download, and upload speeds, as well as comprehensive IP geolocation with multiple provider fallbacks. Designed for reliability, performance, and ease of deployment.

---

## 🚀 **Quick Install & Deploy**

### One-Command Production Deployment

```bash
# Download and run the installation script
curl -fsSL https://raw.githubusercontent.com/Krea-University/speed-test-server/main/install.sh | bash -s -- yourdomain.com admin@yourdomain.com
```

### Manual Installation

1. **Clone and prepare**:
   ```bash
   git clone https://github.com/Krea-University/speed-test-server.git
   cd speed-test-server
   ./prepare-deploy.sh
   ```

2. **Deploy to server**:
   ```bash
   scp -r /tmp/speed-test-server root@your-server:/tmp/
   ssh root@your-server "cd /tmp/speed-test-server && ./deploy.sh yourdomain.com admin@yourdomain.com"
   ```

3. **For environments without TTY (CI/CD, automation)**:
   ```bash
   # Option 1: Use --no-tty flag
   ./deploy.sh --no-tty yourdomain.com admin@yourdomain.com
   
   # Option 2: Use dedicated no-TTY wrapper
   ./deploy-no-tty.sh yourdomain.com admin@yourdomain.com
   
   # Option 3: Set environment variable
   export DOCKER_NONINTERACTIVE=1
   ./deploy.sh yourdomain.com admin@yourdomain.com
   ```

4. **Access your application**:
   ```
   🌐 Application: https://yourdomain.com
   📚 API Docs: https://yourdomain.com/swagger/index.html
   💓 Health: https://yourdomain.com/healthz
   ```

### What You Get

✅ **Docker containers** with auto-restart  
✅ **Daily MySQL backups** at `/var/backup/speed-test-server/`  
✅ **SSL certificates** with auto-renewal (Let's Encrypt)  
✅ **Nginx reverse proxy** with security headers  
✅ **Admin API key** auto-generated  
✅ **Rate limiting** and authentication  
✅ **Swagger documentation** built-in  
✅ **Health monitoring** for all services  

---

## ✨ Features

* **🚀 Speed Testing**
  * `/ping` for round-trip latency measurement
  * `/ws` WebSocket endpoint for jitter measurement
  * `/download?size=...` streams random data for throughput tests
  * `/upload` accepts arbitrary bytes for upload speed testing

* **🌍 IP Geolocation**
  * `/ip` returns comprehensive IP information with automatic provider fallback
  * **Multiple providers**: ipinfo.io → ip-api.com → freeipapi.com
  * **Rich data**: IP, city, region, country, ISP, ASN, timezone, postal code

* **📊 Server Information**
  * `/healthz` for health checks and monitoring
  * `/version` for application version information
  * `/config` for client configuration sharing

* **🏗️ Professional Architecture**
  * Clean, modular codebase with proper separation of concerns
  * Comprehensive error handling and logging
  * Graceful shutdown and signal handling
  * Security headers and CORS support
  * Docker support with multi-stage builds

---

## 📁 Project Structure

The project follows Go best practices with a clean, modular architecture:

```
speed-test-server/
├── cmd/speed-test-server/  # Application entry point
│   └── main.go
├── internal/               # Private application code
│   ├── config/            # Configuration constants
│   ├── handlers/          # HTTP request handlers
│   ├── ipservice/         # IP geolocation providers
│   ├── middleware/        # HTTP middleware
│   ├── server/           # Server setup and routing
│   └── types/            # Data structures
├── client/               # Example client implementation
├── docs/                # Additional documentation
├── Dockerfile           # Container configuration
├── Makefile            # Build automation
└── README.md           # This file
```

---

## 🚀 Quick Start

### Prerequisites

* Go 1.21+ 
* (Optional) Docker for containerized deployment

### Build and Run

```bash
# Clone the repository
git clone https://github.com/Krea-University/speed-test-server.git
cd speed-test-server

# Build and run using Make
make build
make run

# Or run directly
go run ./cmd/speed-test-server
```

The server will start on port 8080 by default.

---

## 🔧 Configuration

### Environment Variables

| Variable      | Default | Description                           |
|---------------|---------|---------------------------------------|
| `PORT`        | 8080    | HTTP server port                      |
| `IPINFO_TOKEN`| (provided) | ipinfo.io API token (optional)    |

### Setup

1. Copy the example environment file:
   ```bash
   cp .env.example .env
   ```

2. Edit `.env` with your preferred settings:
   ```bash
   PORT=8080
   IPINFO_TOKEN=your_token_here
   ```

---

## 🌐 API Endpoints

### `GET /ping`

Returns server timestamp in nanoseconds. Use for latency measurement.

### `GET /download?size=BYTES`

Streams incompressible random data of given size (default: 50 MiB).
Useful for measuring download throughput.

### `POST /upload`

Accepts raw body data, discards it, and returns total bytes received.
Used to measure upload throughput.

### `GET /ip`

Returns comprehensive client IP information with automatic provider fallback.

**Example Response:**
```json
{
  "ip": "8.8.8.8",
  "city": "Mountain View",
  "region": "California",
  "country": "US", 
  "location": "37.4056,-122.0775",
  "postal": "94043",
  "timezone": "America/Los_Angeles",
  "isp": "Google LLC",
  "asn": "AS15169 Google LLC",
  "source": "ipinfo.io"
}
```

**Provider Fallback Chain:**
1. **ipinfo.io** - Primary provider with detailed information
2. **ip-api.com** - Secondary provider, free service
3. **freeipapi.com** - Tertiary provider for basic geolocation

### `GET /ws`

WebSocket endpoint for jitter measurement. Clients can send messages and receive echoed responses with server timestamps for precise timing analysis.

### `GET /healthz`

Simple health check, responds `ok`.

### `GET /version`

Returns version string or git commit hash.

---

## Installation

### Prerequisites

* Go 1.21+
* (Optional) Reverse proxy (Caddy/Nginx) for TLS

### Clone and build

```bash
git clone https://github.com/Krea-University/speed-test-server.git
cd speed-test-server
go mod tidy
go build -o speed-test-server .
```

### Run

```bash
./speed-test-server
```

By default, server listens on `:8080`.

### Using Make

The project includes a Makefile for common tasks:

```bash
# Build the application
make build

# Run the application
make run

# Run tests
make test

# Format code
make fmt

# Clean build artifacts
make clean

# Build Docker image
make docker-build

# Run Docker container
make docker-run
```

---

## 🧪 Testing & Development

### Run Tests

```bash
# Run all tests
make test

# Run tests with coverage
make test-coverage

# Run benchmarks  
make bench
```

### Development Mode

```bash
# Install development tools
make dev-tools

# Run with live reload
make dev
```

### Using the Test Client

```bash
cd client
go run main.go
```

This will run a comprehensive speed test against your server and display results.

---

## 🌍 IP Geolocation Providers

The server uses multiple IP geolocation providers with automatic fallback:

### Provider Details

| Provider | Type | Rate Limits | Data Quality | API Key Required |
|----------|------|-------------|--------------|------------------|
| **ipinfo.io** | Primary | 50k/month free | Excellent | Yes (free tier) |
| **ip-api.com** | Secondary | 45 req/min | Good | No |  
| **freeipapi.com** | Tertiary | Unlimited | Basic | No |

### Fallback Behavior

1. **Primary**: Attempts ipinfo.io with your API token
2. **Secondary**: Falls back to ip-api.com if primary fails
3. **Tertiary**: Uses freeipapi.com if secondary fails  
4. **Graceful**: Returns basic IP info if all providers fail

See [docs/API_PROVIDERS.md](docs/API_PROVIDERS.md) for detailed provider information.

---

## 🛠️ Development

### Available Make Commands

```bash
make build          # Build the application
make run            # Run the application  
make test           # Run tests
make test-coverage  # Run tests with coverage
make clean          # Clean build artifacts
make fmt            # Format code
make lint           # Lint code
make deps           # Install dependencies
make dev            # Development mode with live reload
make dev-tools      # Install development tools
make docker-build   # Build Docker image
make docker-run     # Run Docker container
make build-all      # Build for multiple platforms
```

---

## 🚀 Production Deployment

### Docker Production Deployment (Recommended)

The application includes a comprehensive Docker-based production deployment with:

- **Auto-restart**: All containers restart automatically unless stopped
- **Daily MySQL backups**: Automated backups at 2:00 AM stored in `/var/backup/speed-test-server`
- **SSL with auto-renewal**: Let's Encrypt certificates renewed every 40 days
- **Health monitoring**: Built-in health checks for all services
- **Easy management**: Simple scripts for common operations

#### Quick Deployment

1. **Prepare your server** (Ubuntu/CentOS with Docker):
   ```bash
   # Run this script to prepare deployment package
   ./prepare-deploy.sh
   ```

2. **Copy to your server**:
   ```bash
   scp -r /tmp/speed-test-server root@your-server:/tmp/
   ```

3. **Deploy on server**:
   ```bash
   ssh root@your-server
   cd /tmp/speed-test-server
   ./deploy.sh speedtest.yourdomain.com admin@yourdomain.com
   ```

#### Management Commands

After deployment, use these commands in `/opt/speed-test-server/`:

```bash
# Service Management
./start.sh          # Start all services
./stop.sh           # Stop all services  
./restart.sh        # Restart all services
./status.sh         # Check service status
./logs.sh [service] # View logs (app, mysql, nginx, backup)

# Backup & Restore
./backup-now.sh     # Manual backup
./restore.sh file   # Restore from backup
ls /var/backup/speed-test-server/  # View backups

# SSL & Updates
./renew-ssl.sh      # Renew SSL certificates
./update.sh         # Update application to latest version
./version.sh        # Show current version information
./version.sh --check-updates  # Check for available updates
```

#### Update Management

The speed test server includes intelligent update tools:

```bash
# Check current version and status
./version.sh

# Check for available updates
./version.sh --check-updates

# Update to latest version (with automatic backup)
sudo ./update.sh

# Force update (skip version check)
sudo ./update.sh --force

# Update from specific branch
sudo ./update.sh --branch=development
```

**Update Features:**
- **Automatic backup**: Creates backup before updating
- **Zero-downtime**: Graceful service restart
- **Rollback support**: Easy rollback if update fails
- **Health verification**: Ensures services work after update
- **Docker rebuild**: Updates containers with latest dependencies

#### Auto-Features

- **Auto-restart**: Containers restart automatically on failure or reboot
- **Daily backups**: MySQL data backed up daily at 2:00 AM
- **SSL renewal**: Certificates renewed automatically every 40 days  
- **Health checks**: All services monitored for health
- **30-day backup retention**: Old backups cleaned up automatically

#### Backup Location

All MySQL backups are stored in `/var/backup/speed-test-server/` with the format:
- `speedtest_backup_YYYYMMDD_HHMMSS.sql.gz` (daily automated)
- `manual_backup_YYYYMMDD_HHMMSS.sql.gz` (manual backups)

### Alternative: Docker Compose Only

For development or custom deployments:

```bash
# Use the specialized Docker deployment script
./deploy-docker.sh yourdomain.com admin@yourdomain.com
```

---

## Development Deployment

### With Caddy (TLS + HTTP/2)

```Caddyfile
speed.krea.edu.in {
    reverse_proxy localhost:8080
}
```

---

## 🐳 Development Docker

### Using Docker

```bash
# Build the image
make docker-build

# Run the container
make docker-run
```

### Manual Docker Commands

```bash
# Build
docker build -t speed-test-server .

# Run with port mapping
docker run -p 8080:8080 -e IPINFO_TOKEN=your_token speed-test-server
```

### With Docker Compose (Development)

```yaml
version: '3.8'
services:
  speed-test-server:
    build: .
    ports:
      - "8080:8080"
    environment:
      - PORT=8080
      - IPINFO_TOKEN=your_token_here
    restart: unless-stopped
```

---

## 🛠️ Troubleshooting

### TTY Issues

If you encounter "the input device is not a TTY" errors during deployment:

```bash
# Option 1: Use --no-tty flag
./deploy.sh --no-tty yourdomain.com

# Option 2: Use dedicated no-TTY wrapper
./deploy-no-tty.sh yourdomain.com

# Option 3: Force non-interactive mode with environment variable
export DOCKER_NONINTERACTIVE=1
./deploy.sh yourdomain.com

# Option 4: For individual management scripts
./backup-now.sh --no-tty
./restore.sh --no-tty backup_file.sql.gz
./renew-ssl.sh --no-tty
```

### Automated Deployment (CI/CD)

For automated deployments without user interaction:

```bash
# Jenkins, GitHub Actions, GitLab CI, etc.
export DOCKER_NONINTERACTIVE=1
export DEBIAN_FRONTEND=noninteractive
./deploy-no-tty.sh yourdomain.com admin@yourdomain.com
```

### Common Issues

- **Docker not found**: Install Docker and Docker Compose first
- **Permission denied**: Run deployment script as root (`sudo`)
- **Port conflicts**: Ensure ports 80, 443, 3306, 8080 are available
- **SSL certificate issues**: Check domain DNS points to server IP

### Log Analysis

```bash
# View service logs
./logs.sh app        # Application logs
./logs.sh mysql      # Database logs
./logs.sh nginx      # Web server logs
./logs.sh backup     # Backup service logs

# Check service status
./status.sh
```

---

## Roadmap

* [x] Multi-threaded chunked download for even smoother graphs
* [x] Persistent metrics logging
* [x] Admin dashboard for server load & test history
* [x] Rate limiting per client

---

## License

MIT License © 2025 Krea University

---
