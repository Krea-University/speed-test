# Krea Speed Test Server

Krea Speed Test Server is a lightweight Golang service for self-hosted internet speed testing. It provides endpoints to measure latency, jitter, download, and upload speeds, as well as IP lookup with optional geolocation. It is designed to mimic features of popular tools like Ookla, but fully under your control.

---

## Features

* **Latency & Jitter**

  * `/ping` for round-trip latency
  * `/ws` WebSocket beacons for jitter measurement

* **Download Speed**

  * `/download?size=...` streams random data for throughput tests
  * Parallelizable for realistic load

* **Upload Speed**

  * `/upload` accepts arbitrary bytes and counts total received

* **IP Lookup**

  * `/ip` returns client’s public IP, ASN, ISP, and location (if provider configured)

* **Server Metadata**

  * `/healthz` for liveness checks
  * `/version` for release version or git hash
  * `/config` to share test parameters with clients

---

## Endpoints

### `GET /ping`

Returns server timestamp in nanoseconds. Use for latency measurement.

### `GET /download?size=BYTES`

Streams incompressible random data of given size (default: 50 MiB).
Useful for measuring download throughput.

### `POST /upload`

Accepts raw body data, discards it, and returns total bytes received.
Used to measure upload throughput.

### `GET /ws`

WebSocket endpoint. Sends server timestamps periodically (100 ms default).
Clients can measure jitter based on arrival deltas.

### `GET /ip`

Returns client IP and optional geolocation info.
Example:

```json
{
  "ip": "203.0.113.25",
  "asn": "AS13335",
  "org": "Example ISP",
  "city": "Singapore",
  "region": "Singapore",
  "country": "SG",
  "loc": "1.2897,103.8501"
}
```

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
git clone https://github.com/your-org/krea-speedtest-server.git
cd krea-speedtest-server
go mod tidy
go build -o krea-speedtest
```

### Run

```bash
./krea-speedtest
```

By default, server listens on `:8080`.

---

## Configuration

Environment variables:

| Variable             | Default           | Description                                                 |
| -------------------- | ----------------- | ----------------------------------------------------------- |
| `PORT`               | 8080              | Port to listen on                                           |
| `IP_PROVIDER`        | none              | `none`, `ipinfo`, `ip-api`, `ipapi_co`, `ipwhois`, `custom` |
| `IP_TOKEN`           | -                 | API token (if provider requires)                            |
| `IP_CUSTOM_URL`      | -                 | Custom provider endpoint, `{ip}` placeholder supported      |
| `MAX_DOWNLOAD_SIZE`  | 52428800 (50 MiB) | Default download size                                       |
| `UPLOAD_READ_BUFFER` | 262144            | Read buffer size in bytes                                   |
| `WS_INTERVAL_MS`     | 100               | Interval for WebSocket jitter packets                       |

Example:

```bash
PORT=8080 IP_PROVIDER=ipinfo IP_TOKEN=your_token ./krea-speedtest
```

---

## Deployment

### With Caddy (TLS + HTTP/2)

```Caddyfile
speed.krea.edu.in {
    reverse_proxy localhost:8080
}
```

### With Docker

```Dockerfile
FROM golang:1.21 as build
WORKDIR /app
COPY . .
RUN go build -o krea-speedtest

FROM gcr.io/distroless/base
COPY --from=build /app/krea-speedtest /krea-speedtest
EXPOSE 8080
CMD ["/krea-speedtest"]
```

---

## Roadmap

* [ ] Multi-threaded chunked download for even smoother graphs
* [ ] Persistent metrics logging
* [ ] Admin dashboard for server load & test history
* [ ] Rate limiting per client

---

## License

MIT License © 2025 Krea University

---
