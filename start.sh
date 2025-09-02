#!/bin/bash

# GitHub COSPACE V2Ray Setup Script
# Automatically generates configurations for V2Ray behind Nginx

# Get current COSPACE name
COSPACE_NAME=$(echo $CODEPACE_NAME | sed 's/-[0-9a-f]*$//')  # Remove hash suffix if present
if [ -z "$COSPACE_NAME" ]; then
    echo "Error: Not running in a GitHub COSPACE environment"
    exit 1
fi

# Generate random UUID
UUID=$(uuidgen)

# Create directory structure
mkdir -p nginx/html v2ray logs

# Generate docker-compose.yml
cat > docker-compose.yml << EOF
version: '3.8'

services:
  nginx:
    image: nginx:alpine
    container_name: nginx-v2ray
    ports:
      - "433:433"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/html:/usr/share/nginx/html:ro
      - ./logs:/var/log/nginx
    depends_on:
      - v2ray
    restart: unless-stopped

  v2ray:
    image: v2ray/official:latest
    container_name: v2ray-server
    volumes:
      - ./v2ray/v2ray.json:/etc/v2ray/config.json:ro
    restart: unless-stopped
EOF

# Generate nginx.conf
cat > nginx/nginx.conf << EOF
events {
    worker_connections 1024;
}

http {
    log_format main '\$remote_addr - \$remote_user [\$time_local] '
                    '"\$request" \$status \$body_bytes_sent '
                    '"\$http_referer" "\$http_user_agent"';

    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log;

    server {
        listen 433;
        server_name ${COSPACE_NAME}-433.app.github.dev;

        location / {
            root /usr/share/nginx/html;
            index index.html;
        }

        location /v2 {
            proxy_pass http://v2ray:10000;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host \$host;
        }
    }
}
EOF

# Generate v2ray.json
cat > v2ray/v2ray.json << EOF
{
  "inbounds": [
    {
      "port": 10000,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "${UUID}",
            "alterId": 64
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/v2"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}
EOF

# Generate index.html
cat > nginx/html/index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>V2Ray Proxy</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .container { max-width: 600px; margin: 0 auto; }
        .info { background: #f5f5f5; padding: 15px; border-radius: 5px; margin: 20px 0; }
        .config { background: #e8f4f8; padding: 15px; border-radius: 5px; }
        .url { word-break: break-all; }
    </style>
</head>
<body>
    <div class="container">
        <h1>V2Ray WebSocket Proxy</h1>
        <div class="info">
            <h2>Server Information</h2>
            <p><strong>Address:</strong> ${COSPACE_NAME}-433.app.github.dev</p>
            <p><strong>Port:</strong> 433</p>
            <p><strong>Path:</strong> /v2</p>
            <p><strong>UUID:</strong> ${UUID}</p>
        </div>
        
        <div class="config">
            <h2>Client Configuration</h2>
            <h3>VMess URL:</h3>
            <p class="url">vmess://$(echo -n "aes-128-gcm:${UUID}@${COSPACE_NAME}-433.app.github.dev:433?path=/v2&security=tls" | base64)</p>
            
            <h3>JSON Configuration:</h3>
            <pre>{
  "inbounds": [
    {
      "port": 10808,
      "listen": "127.0.0.1",
      "protocol": "socks",
      "settings": {
        "auth": "noauth",
        "udp": true
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "vmess",
      "settings": {
        "vnext": [
          {
            "address": "${COSPACE_NAME}-433.app.github.dev",
            "port": 433,
            "users": [
              {
                "id": "${UUID}",
                "alterId": 64
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/v2"
        }
      }
    }
  ]
}</pre>
        </div>
        
        <div class="info">
            <h2>Instructions</h2>
            <ol>
                <li>Start the services: <code>docker-compose up -d</code></li>
                <li>Access your proxy at: <a href="https://${COSPACE_NAME}-433.app.github.dev/v2">https://${COSPACE_NAME}-433.app.github.dev/v2</a></li>
                <li>Use the VMess URL or JSON configuration in your V2Ray client</li>
                <li>Set system proxy to 127.0.0.1:10808 (SOCKS) or 127.0.0.1:10809 (HTTP)</li>
            </ol>
        </div>
    </div>
</body>
</html>
EOF

# Generate client configuration file
cat > client-config.json << EOF
{
  "inbounds": [
    {
      "port": 10808,
      "listen": "127.0.0.1",
      "protocol": "socks",
      "settings": {
        "auth": "noauth",
        "udp": true
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "vmess",
      "settings": {
        "vnext": [
          {
            "address": "${COSPACE_NAME}-433.app.github.dev",
            "port": 433,
            "users": [
              {
                "id": "${UUID}",
                "alterId": 64
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/v2"
        }
      }
    }
  ]
}
EOF

# Generate VMess URL
VMESS_URL="vmess://$(echo -n "aes-128-gcm:${UUID}@${COSPACE_NAME}-433.app.github.dev:433?path=/v2&security=tls" | base64)"

# Print setup information
echo "=========================================="
echo "GitHub COSPACE V2Ray Setup Complete!"
echo "=========================================="
echo "COSPACE Name: $COSPACE_NAME"
echo "UUID: $UUID"
echo ""
echo "Server URLs:"
echo "Web Interface: https://${COSPACE_NAME}-433.app.github.dev"
echo "V2Ray WebSocket: https://${COSPACE_NAME}-433.app.github.dev/v2"
echo ""
echo "Client Configuration:"
echo "VMess URL: $VMESS_URL"
echo "JSON Config: client-config.json"
echo ""
echo "To start services:"
echo "docker-compose up -d"
echo ""
echo "To view logs:"
echo "docker logs nginx-v2ray"
echo "docker logs v2ray-server"
echo "tail -f logs/access.log"
echo "=========================================="

# Create start script
cat > start.sh << EOF
#!/bin/bash
docker-compose up -d
echo "Services started!"
echo "Access at: https://${COSPACE_NAME}-433.app.github.dev"
EOF

chmod +x start.sh

echo "Scripts created:"
echo "- docker-compose.yml: Container definitions"
echo "- nginx/: Nginx configuration and web content"
echo "- v2ray/: V2Ray server configuration"
echo "- client-config.json: Client configuration file"
echo "- start.sh: Quick start script"
echo "- logs/: Directory for log files"
