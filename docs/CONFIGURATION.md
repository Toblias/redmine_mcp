# Server Configuration Guide

This guide covers web server configuration for production deployments of the Redmine MCP Server plugin.

## Table of Contents

- [Overview](#overview)
- [Nginx Configuration](#nginx-configuration)
- [Apache Configuration](#apache-configuration)
- [Application Server Considerations](#application-server-considerations)
- [SSL/TLS Configuration](#ssltls-configuration)
- [Load Balancer Configuration](#load-balancer-configuration)
- [Performance Tuning](#performance-tuning)
- [Security Best Practices](#security-best-practices)

## Overview

The Redmine MCP Server uses HTTP + SSE (Server-Sent Events) transport. SSE requires special web server configuration to handle long-lived connections properly. Without proper configuration, proxy servers may buffer responses or prematurely close connections.

### Key Requirements

1. **Disable buffering** for the `/mcp` SSE endpoint
2. **Allow long-lived connections** (up to the configured `sse_timeout`, default 1 hour)
3. **Preserve headers** including `X-Redmine-API-Key` for authentication
4. **Support HTTP/1.1** with chunked transfer encoding

## Nginx Configuration

Nginx is the recommended reverse proxy for Redmine MCP Server due to excellent SSE support.

### Basic Configuration

```nginx
upstream redmine {
    server 127.0.0.1:3000;
    # Or for Unix socket:
    # server unix:/path/to/redmine/tmp/sockets/puma.sock;
}

server {
    listen 443 ssl http2;
    server_name redmine.example.com;

    # SSL configuration (see SSL/TLS section)
    ssl_certificate /path/to/certificate.crt;
    ssl_certificate_key /path/to/private.key;

    # Redmine root
    root /path/to/redmine/public;

    # Increase timeouts for SSE connections
    proxy_read_timeout 3600s;  # Match or exceed sse_timeout setting
    proxy_connect_timeout 10s;
    proxy_send_timeout 10s;

    # Standard Redmine proxy settings
    location / {
        try_files $uri @redmine;
    }

    location @redmine {
        proxy_pass http://redmine;
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $http_host;

        # Preserve API key header
        proxy_pass_header X-Redmine-API-Key;

        # Standard proxy settings
        proxy_redirect off;
        proxy_buffering off;
    }

    # MCP SSE endpoint - special configuration
    location /mcp {
        proxy_pass http://redmine;
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $http_host;

        # Preserve API key header
        proxy_pass_header X-Redmine-API-Key;

        # Critical SSE settings
        proxy_buffering off;                    # Disable response buffering
        proxy_cache off;                        # Disable caching
        proxy_read_timeout 3600s;               # Match sse_timeout (1 hour default)
        proxy_http_version 1.1;                 # Required for chunked transfer
        proxy_set_header Connection '';         # Clear connection header

        # Tell upstream not to buffer (Rails ActionController::Live)
        proxy_set_header X-Accel-Buffering no;

        # Chunked transfer encoding for streaming
        chunked_transfer_encoding on;

        # Optional: Add CORS headers if MCP client is browser-based
        # add_header Access-Control-Allow-Origin *;
        # add_header Access-Control-Allow-Methods 'GET, POST, OPTIONS';
        # add_header Access-Control-Allow-Headers 'X-Redmine-API-Key, Content-Type';
    }

    # Health check endpoint (no auth required)
    location /mcp/health {
        proxy_pass http://redmine;
        proxy_set_header Host $http_host;
        proxy_buffering off;
        access_log off;  # Reduce log noise from health checks
    }

    # Optional: Rate limiting at nginx level
    # limit_req_zone $binary_remote_addr zone=mcp_limit:10m rate=60r/m;
    # location /mcp {
    #     limit_req zone=mcp_limit burst=10 nodelay;
    #     # ... rest of config
    # }
}
```

### Key Settings Explained

| Setting | Purpose |
|---------|---------|
| `proxy_buffering off` | Prevents Nginx from buffering responses, allowing immediate streaming |
| `proxy_cache off` | Disables caching for SSE responses |
| `proxy_read_timeout 3600s` | Allows connections to remain open for up to 1 hour (match plugin setting) |
| `proxy_http_version 1.1` | Required for HTTP/1.1 chunked transfer encoding |
| `proxy_set_header Connection ''` | Clears connection header to prevent "close" directive |
| `chunked_transfer_encoding on` | Enables streaming response chunks |
| `X-Accel-Buffering no` | Header that Rails reads to confirm no buffering |

### Testing Nginx Configuration

```bash
# Test configuration syntax
sudo nginx -t

# Reload without downtime
sudo nginx -s reload

# Test SSE connection
curl -N -H "X-Redmine-API-Key: your_key_here" \
     https://redmine.example.com/mcp

# Should output ping events every 30 seconds (default heartbeat_interval)
```

## Apache Configuration

Apache can also proxy SSE connections with proper configuration.

### Apache 2.4+ Configuration

First, enable required modules:

```bash
sudo a2enmod proxy
sudo a2enmod proxy_http
sudo a2enmod headers
sudo a2enmod ssl
```

Configuration:

```apache
<VirtualHost *:443>
    ServerName redmine.example.com

    # SSL configuration
    SSLEngine on
    SSLCertificateFile /path/to/certificate.crt
    SSLCertificateKeyFile /path/to/private.key

    DocumentRoot /path/to/redmine/public

    # Increase timeouts for SSE
    ProxyTimeout 3600
    Timeout 3600

    # Preserve host header
    ProxyPreserveHost On

    # Standard Redmine proxy
    <Location />
        ProxyPass http://127.0.0.1:3000/
        ProxyPassReverse http://127.0.0.1:3000/

        # Preserve headers
        RequestHeader set X-Forwarded-Proto "https"
        RequestHeader set X-Forwarded-Host "%{HTTP_HOST}e"
    </Location>

    # MCP SSE endpoint - special configuration
    <Location /mcp>
        ProxyPass http://127.0.0.1:3000/mcp disablereuse=on
        ProxyPassReverse http://127.0.0.1:3000/mcp

        # Critical for SSE
        SetEnv proxy-nokeepalive 1
        SetEnv proxy-sendcl 0
        SetEnv proxy-sendchunked 1

        # Disable buffering
        SetEnv proxy-initial-not-pooled 1

        # Preserve headers
        RequestHeader set X-Forwarded-Proto "https"
        RequestHeader set X-Forwarded-Host "%{HTTP_HOST}e"
    </Location>

    # Health check
    <Location /mcp/health>
        ProxyPass http://127.0.0.1:3000/mcp/health
        ProxyPassReverse http://127.0.0.1:3000/mcp/health
    </Location>

    # Optional: Rate limiting with mod_ratelimit
    # <Location /mcp>
    #     SetOutputFilter RATE_LIMIT
    #     SetEnv rate-limit 400
    # </Location>
</VirtualHost>
```

### Apache Key Settings

| Setting | Purpose |
|---------|---------|
| `ProxyTimeout 3600` | Allows connections to stay open for 1 hour |
| `disablereuse=on` | Prevents connection pooling (important for SSE) |
| `proxy-nokeepalive 1` | Disables keep-alive to prevent buffering issues |
| `proxy-sendchunked 1` | Enables chunked transfer encoding |
| `proxy-initial-not-pooled 1` | Prevents connection from entering pool prematurely |

### Testing Apache Configuration

```bash
# Test configuration
sudo apachectl configtest

# Reload
sudo systemctl reload apache2

# Test SSE
curl -N -H "X-Redmine-API-Key: your_key_here" \
     https://redmine.example.com/mcp
```

## Application Server Considerations

### Puma (Recommended)

Puma has excellent support for ActionController::Live (required for SSE).

**Configuration** (`config/puma.rb` or use environment variables):

```ruby
# Minimum 2 workers recommended for SSE
workers ENV.fetch("WEB_CONCURRENCY") { 2 }

# Threads per worker
threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
threads threads_count, threads_count

# Preload app for memory efficiency
preload_app!

# Optional: Increase worker timeout for long-running requests
worker_timeout 60

# Optional: Tune for SSE connections
# Each SSE connection holds a thread, so increase thread pool if many clients
# threads 10, 10  # 10 threads per worker
```

**Important:** Each SSE connection holds a thread. With default settings (5 threads × 2 workers = 10 threads), you can support ~10 concurrent SSE clients. Increase threads if you need more:

```bash
# Example: Support 50 concurrent SSE clients (25 threads × 2 workers)
RAILS_MAX_THREADS=25 bundle exec puma -C config/puma.rb
```

### Passenger

Passenger also supports SSE but requires specific configuration.

**Configuration** (`config/passenger.rb` or virtual host):

```ruby
# Increase pool size to handle SSE connections
passenger_max_pool_size 20

# Increase max instances per app
passenger_max_instances_per_app 10

# Disable buffering for SSE
passenger_buffering off

# Increase timeout
passenger_timeout 3600
```

**Nginx + Passenger:**

```nginx
location /mcp {
    passenger_enabled on;
    passenger_app_root /path/to/redmine;
    passenger_buffering off;
    passenger_timeout 3600;

    # ... other settings from Nginx section
}
```

**Apache + Passenger:**

```apache
<Location /mcp>
    PassengerEnabled on
    PassengerAppRoot /path/to/redmine
    PassengerBuffering off
    PassengerMaxRequests 0
</Location>
```

### Unicorn

Unicorn does **not** support ActionController::Live. SSE will not work with Unicorn. Use Puma or Passenger instead.

## SSL/TLS Configuration

Always use HTTPS for production MCP servers to protect API keys in transit.

### Recommended SSL Settings

```nginx
# Modern SSL configuration (TLS 1.2+ only)
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
ssl_prefer_server_ciphers on;

# SSL session caching
ssl_session_cache shared:SSL:10m;
ssl_session_timeout 10m;

# OCSP stapling
ssl_stapling on;
ssl_stapling_verify on;

# HSTS (optional, forces HTTPS)
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
```

### Let's Encrypt (Free SSL)

```bash
# Install certbot
sudo apt-get install certbot python3-certbot-nginx

# Obtain certificate (Nginx)
sudo certbot --nginx -d redmine.example.com

# Or for Apache
sudo certbot --apache -d redmine.example.com

# Auto-renewal is configured automatically
```

## Load Balancer Configuration

When using a load balancer (AWS ALB, HAProxy, etc.), configure it for SSE support.

### AWS Application Load Balancer (ALB)

1. **Target Group Settings:**
   - Health check path: `/mcp/health`
   - Health check interval: 30s
   - Timeout: 30s (default)
   - Idle timeout: **3600s** (must match or exceed SSE timeout)

2. **Listener Rules:**
   - Forward `/mcp` to target group
   - Preserve `X-Redmine-API-Key` header

3. **Connection Settings:**
   - Enable connection draining (300s)
   - Sticky sessions: Not required for MCP

**ALB Idle Timeout (Critical):**

```bash
# Increase ALB idle timeout to 1 hour (default is 60s)
aws elbv2 modify-load-balancer-attributes \
  --load-balancer-arn arn:aws:elasticloadbalancing:... \
  --attributes Key=idle_timeout.timeout_seconds,Value=3600
```

### HAProxy Configuration

```haproxy
global
    log /dev/log local0
    maxconn 4096

defaults
    mode http
    timeout connect 10s
    timeout client 3600s    # Match SSE timeout
    timeout server 3600s    # Match SSE timeout

frontend redmine_https
    bind *:443 ssl crt /path/to/certificate.pem
    default_backend redmine_servers

backend redmine_servers
    option httplog
    option http-server-close
    option forwardfor

    # Health check
    option httpchk GET /mcp/health

    # Preserve headers
    http-request set-header X-Forwarded-Proto https

    # SSE support - disable buffering
    no option http-buffer-request
    server redmine1 127.0.0.1:3000 check
```

## Performance Tuning

### Rate Limiting

Protect your server from excessive requests with rate limiting.

**Nginx rate limiting:**

```nginx
# Define rate limit zone (60 requests/min = 1 request/sec)
limit_req_zone $binary_remote_addr zone=mcp_limit:10m rate=1r/s;

location /mcp {
    # Allow burst of 10 requests, then enforce rate
    limit_req zone=mcp_limit burst=10 nodelay;

    # Return 429 with custom message
    limit_req_status 429;

    # ... rest of config
}
```

**Application-level:** The plugin has built-in rate limiting (configurable in admin settings). This is per-user and more granular than IP-based nginx rate limiting.

### Connection Limits

Limit concurrent SSE connections to prevent resource exhaustion:

**Puma threads:** Each SSE connection holds a thread. Calculate required threads:

```
Required threads = Expected concurrent SSE clients + Normal HTTP requests
Example: 20 SSE clients + 10 HTTP requests = 30 threads minimum
```

**System limits:** Check and increase if needed:

```bash
# Check current limits
ulimit -n

# Increase file descriptor limit (add to /etc/security/limits.conf)
* soft nofile 65536
* hard nofile 65536

# For systemd services (e.g., /etc/systemd/system/redmine.service)
[Service]
LimitNOFILE=65536
```

### Database Connection Pooling

SSE connections can hold database connections. Ensure your pool is sized appropriately:

```yaml
# config/database.yml
production:
  adapter: postgresql
  pool: <%= ENV.fetch("DB_POOL") { 25 } %>  # Increase if many SSE clients
  timeout: 5000
```

Rule of thumb: `DB_POOL >= Puma threads × Puma workers`

### Monitoring

Monitor SSE connection health:

```bash
# Check active SSE connections (Nginx)
sudo ss -tn | grep :443 | wc -l

# Check Puma thread usage
ps -T -p $(pgrep -f puma) | wc -l

# Watch logs for SSE disconnect events
tail -f log/production.log | grep "SSE"
```

## Security Best Practices

### API Key Protection

1. **Use dedicated API keys** for MCP clients (not admin personal keys)
2. **Rotate keys regularly** (every 90 days recommended)
3. **Revoke compromised keys immediately** (My Account > Reset API access key)
4. **Monitor API usage** in Redmine logs

### Network Security

```nginx
# Restrict MCP access to specific IPs (optional)
location /mcp {
    allow 10.0.0.0/8;      # Internal network
    allow 192.168.1.0/24;  # VPN
    deny all;

    # ... rest of config
}
```

### Write Protection

Keep "Enable Write Operations" **disabled** unless absolutely necessary. This restricts AI to read-only access.

### HTTPS Only

```nginx
# Redirect HTTP to HTTPS
server {
    listen 80;
    server_name redmine.example.com;
    return 301 https://$server_name$request_uri;
}
```

### Request Size Limits

The plugin limits requests to 1MB. Optionally add web server limits:

```nginx
# Nginx
client_max_body_size 1M;
```

```apache
# Apache
LimitRequestBody 1048576
```

## Troubleshooting

### SSE Connections Close Immediately

**Symptoms:** SSE connection closes after a few seconds

**Causes:**
- Nginx buffering enabled
- Load balancer idle timeout too short
- Web server timeout too short

**Solutions:**
1. Check nginx `proxy_buffering off` is set for `/mcp`
2. Verify `proxy_read_timeout >= sse_timeout` setting
3. Check load balancer idle timeout (AWS ALB common issue)
4. Review `log/production.log` for Rails errors

### 502 Bad Gateway

**Symptoms:** `/mcp` returns 502 error

**Causes:**
- Application server not running
- Application server crash during SSE
- Socket/port mismatch in upstream config

**Solutions:**
1. Check application server status: `systemctl status redmine`
2. Verify upstream address matches running server
3. Check `log/puma.stderr.log` or equivalent for crashes
4. Test direct connection to app server (bypass proxy)

### High Memory Usage

**Symptoms:** Redmine process memory grows over time

**Causes:**
- Too many concurrent SSE connections
- Memory leak in application code

**Solutions:**
1. Limit concurrent SSE clients (authentication, firewall rules)
2. Restart Puma workers periodically (Puma supports zero-downtime restart)
3. Monitor with tools like `top`, `htop`, or APM solutions

### Authentication Fails

**Symptoms:** Valid API key returns "Authentication required"

**Causes:**
- `X-Redmine-API-Key` header not forwarded
- Header name mismatch (case-sensitive)

**Solutions:**
1. Check proxy preserves header: `proxy_pass_header X-Redmine-API-Key`
2. Test direct to app server to isolate proxy issue
3. Verify header name exactly matches (case-sensitive)

## Performance Benchmarks

Expected performance on typical hardware (4 CPU, 8GB RAM):

| Metric | Value |
|--------|-------|
| Concurrent SSE clients | 50-100 (limited by threads) |
| Request throughput | 100-200 req/s (tool calls) |
| SSE connection overhead | ~10MB RAM per connection |
| Database queries per request | 1-20 (depending on tool) |

Scale vertically (more CPU/RAM) or horizontally (multiple Redmine instances behind load balancer) as needed.

## Additional Resources

- [Nginx SSE Configuration](https://nginx.org/en/docs/http/ngx_http_proxy_module.html)
- [Apache Proxy Guide](https://httpd.apache.org/docs/2.4/mod/mod_proxy.html)
- [Puma Configuration](https://github.com/puma/puma/blob/master/docs/deployment.md)
- [Let's Encrypt](https://letsencrypt.org/getting-started/)
- [Rails ActionController::Live](https://api.rubyonrails.org/classes/ActionController/Live.html)
