# Domain Configuration Guide

This guide explains how to configure your Krea Speed Test Server with a custom domain instead of localhost.

## Quick Setup

### Option 1: Using the Configuration Script (Recommended)

```bash
# For a domain with HTTPS (recommended for production)
./configure-domain.sh speedtest.yourdomain.com

# For a domain with HTTP (development/testing)
./configure-domain.sh speedtest.yourdomain.com http

# For IP address with custom port
./configure-domain.sh 192.168.1.100:8080 http
```

This script will:
- Create/update your `.env` file with the correct URLs
- Set up Swagger documentation to use your domain
- Configure the client applications to use your domain
- Generate secure passwords and API keys

### Option 2: Manual Configuration

1. **Copy the environment template:**
   ```bash
   cp .env.example .env
   ```

2. **Edit the `.env` file:**
   ```bash
   # External URLs Configuration
   SERVER_URL=https://speedtest.yourdomain.com
   SWAGGER_HOST=speedtest.yourdomain.com
   ```

3. **Deploy with your domain:**
   ```bash
   ./deploy.sh speedtest.yourdomain.com your-email@domain.com
   ```

## Environment Variables Reference

| Variable | Description | Example |
|----------|-------------|---------|
| `SERVER_URL` | Full URL used by client applications | `https://speedtest.example.com` |
| `SWAGGER_HOST` | Host for Swagger API documentation | `speedtest.example.com` |
| `PORT` | Internal container port (usually 8080) | `8080` |

## DNS Configuration

Before deploying, ensure your domain is properly configured:

1. **A Record**: Point your domain to your server's IP address
   ```
   speedtest.yourdomain.com → 192.168.1.100
   ```

2. **CNAME Record** (if using subdomain):
   ```
   speedtest → yourdomain.com
   ```

3. **Verify DNS resolution:**
   ```bash
   nslookup speedtest.yourdomain.com
   dig speedtest.yourdomain.com
   ```

## Deployment Examples

### Production Deployment with Domain
```bash
# Configure domain
./configure-domain.sh speedtest.example.com

# Deploy with SSL
./deploy.sh speedtest.example.com admin@example.com
```

### Development with IP Address
```bash
# Configure for IP access
./configure-domain.sh 192.168.1.100:8080 http

# Deploy without SSL
./deploy.sh 192.168.1.100 admin@example.com
```

### Local Development
```bash
# For local development, keep default localhost settings
# No configuration needed - uses localhost:8080 by default
./setup-dev.sh
```

## Testing Your Configuration

After deployment, test your endpoints:

```bash
# Health check
curl https://speedtest.yourdomain.com/healthz

# API documentation
open https://speedtest.yourdomain.com/swagger/

# Speed test endpoints
curl https://speedtest.yourdomain.com/ping
curl https://speedtest.yourdomain.com/ip

# API endpoints (requires API key)
curl -H 'X-API-Key: demo-api-key-2025' https://speedtest.yourdomain.com/api/tests
```

## Client Applications

After configuring your domain, client applications can connect using:

```bash
# Set the server URL environment variable
export SERVER_URL=https://speedtest.yourdomain.com

# Run the client
./client/speed-test-client
```

Or modify the client code to use your domain directly.

## Troubleshooting

### Common Issues

1. **Domain not resolving:**
   - Check DNS configuration
   - Verify A/CNAME records
   - Test with `nslookup` or `dig`

2. **SSL certificate issues:**
   - Ensure domain points to correct IP
   - Check Let's Encrypt rate limits
   - Verify port 80 and 443 are open

3. **Connection refused:**
   - Check firewall settings
   - Verify Docker containers are running
   - Check nginx configuration

### Logs and Diagnostics

```bash
# Check container status
docker-compose ps

# View application logs
docker-compose logs app

# View nginx logs
docker-compose logs nginx

# Run diagnostics
./diagnose.sh speedtest.yourdomain.com
```

## Security Considerations

1. **Use HTTPS in production:**
   - Always use HTTPS for production deployments
   - Let's Encrypt certificates are automatically configured

2. **Firewall configuration:**
   - Open ports 80 (HTTP) and 443 (HTTPS)
   - Block direct access to port 8080 if not needed

3. **API Keys:**
   - Change default API keys in production
   - Use strong, unique keys for different environments

## Multiple Domains

To support multiple domains (e.g., www and non-www):

1. **Configure nginx for multiple domains:**
   ```bash
   # Edit deploy.sh to include multiple server_name entries
   server_name speedtest.example.com www.speedtest.example.com;
   ```

2. **Get certificates for all domains:**
   ```bash
   ./deploy.sh speedtest.example.com,www.speedtest.example.com admin@example.com
   ```

## Advanced Configuration

For advanced setups, you can modify:

- `deploy.sh` - Main deployment script
- `docker-compose.yml` - Container configuration
- `nginx.conf` - Web server configuration
- `.env` - Environment variables

Refer to the main README.md for detailed configuration options.
