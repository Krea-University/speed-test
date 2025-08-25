# API Providers Documentation

The Speed Test Server uses multiple IP geolocation providers with automatic fallback to ensure reliable service. Here's how the system works:

## Provider Priority Order

1. **ipinfo.io** (Primary)
   - High accuracy and detailed information
   - Requires API token (free tier available)
   - Rate limited but generous limits

2. **ip-api.com** (Secondary)
   - Free service, no API key required
   - Good accuracy for most regions
   - Rate limited to 45 requests per minute

3. **freeipapi.com** (Tertiary)
   - Basic geolocation service
   - Free with no registration required
   - Limited data but reliable as fallback

## Configuration

Set your ipinfo.io token in environment variables:

```bash
export IPINFO_TOKEN="your_token_here"
```

Or use the .env file:

```bash
IPINFO_TOKEN=your_token_here
```

## Fallback Behavior

The system automatically tries providers in order:

1. If ipinfo.io fails → try ip-api.com
2. If ip-api.com fails → try freeipapi.com  
3. If all providers fail → return basic IP only

## Response Format

All providers are normalized to return consistent data:

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

## Adding New Providers

To add a new provider:

1. Implement the `Provider` interface in `internal/ipservice/providers.go`
2. Add the provider to the service in `NewService()`
3. The system will automatically include it in the fallback chain
