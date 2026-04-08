#!/bin/bash
#=========================================================
# HAProxy App Load Balancer Setup Script
# Idempotent - safe to re-run
#=========================================================

set -e

# =========================
# Variables
# =========================
HOSTNAME=${1}
shift
SSL_IP=${2}
shift
SSL_CN=${3}
shift
BACKEND_SERVERS=("$@")

FRONTEND_HTTP_PORT=80
FRONTEND_HTTPS_PORT=443

SSL_DIR="/etc/ssl/siwapp"

BACKEND_HTTP_PORT=8080
BACKEND_HTTPS_PORT=8443

BACKEND_HTTP_NAME="siwapp_http"
BACKEND_HTTPS_NAME="siwapp_https"
HAPROXY_CFG="/etc/haproxy/haproxy.cfg"

# Set Hostname
echo "Setting hostname to ${HOSTNAME}..."
sudo hostnamectl set-hostname "${HOSTNAME}"

# =========================
# Install HAProxy
# =========================
echo "Installing HAProxy..."
sudo apt update
sudo apt install -y haproxy socat
sudo systemctl enable haproxy

# ===============================
# SSL Self-Signed Certificate (idempotent)
# ===============================
if [ ! -f "$SSL_DIR/siwapp.pem" ]; then
  echo "Generating SSL certificate..."
  sudo tee /tmp/siwapp_openssl.cnf > /dev/null <<EOF
[req]
distinguished_name=req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = CA
L = SanFrancisco
O = Siwapp
OU = Dev
CN = $SSL_CN

[v3_req]
subjectAltName = DNS:$SSL_CN,DNS:$SSL_IP
EOF

  sudo mkdir -p "$SSL_DIR"
  sudo openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout "$SSL_DIR/siwapp.key" \
    -out "$SSL_DIR/siwapp.crt" \
    -config /tmp/siwapp_openssl.cnf \
    -extensions v3_req

  sudo cat "$SSL_DIR/siwapp.crt" "$SSL_DIR/siwapp.key" | sudo tee "$SSL_DIR/siwapp.pem" > /dev/null
else
  echo "SSL certificate already exists, skipping"
fi

# =========================
# Generate HAProxy configuration (always overwrite - declarative)
# =========================
echo "Configuring HAProxy..."
sudo tee "$HAPROXY_CFG" > /dev/null <<EOF
global
    log /dev/log    local0
    log /dev/log    local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon
    tune.ssl.default-dh-param 2048

defaults
    log     global
    mode    http
    option  httplog
    option  dontlognull
    timeout connect 5s
    timeout client  50s
    timeout server  50s
    errorfile 400 /etc/haproxy/errors/400.http
    errorfile 403 /etc/haproxy/errors/403.http
    errorfile 408 /etc/haproxy/errors/408.http
    errorfile 500 /etc/haproxy/errors/500.http
    errorfile 502 /etc/haproxy/errors/502.http
    errorfile 503 /etc/haproxy/errors/503.http
    errorfile 504 /etc/haproxy/errors/504.http

frontend http_front
    bind *:${FRONTEND_HTTP_PORT}
    mode http
    option forwardfor
    http-request set-header Host %[req.hdr(Host)]
    default_backend ${BACKEND_HTTP_NAME}

backend ${BACKEND_HTTP_NAME}
    mode http
    balance roundrobin
    cookie SRV_ID insert indirect nocache
EOF

# Add HTTP backend servers
i=1
for server in "${BACKEND_SERVERS[@]}"; do
    echo "    server app${i} $server:$BACKEND_HTTP_PORT check cookie app${i}" | sudo tee -a "$HAPROXY_CFG" > /dev/null
    ((i++))
done

sudo tee -a "$HAPROXY_CFG" > /dev/null <<EOF

frontend https_front
    bind *:${FRONTEND_HTTPS_PORT} ssl crt $SSL_DIR/siwapp.pem
    mode http
    option forwardfor
    http-request set-header Host %[req.hdr(Host)]
    default_backend ${BACKEND_HTTPS_NAME}

backend ${BACKEND_HTTPS_NAME}
    mode http
    balance roundrobin
    cookie SRV_ID insert indirect nocache
EOF

# Add HTTPS backend servers
i=1
for server in "${BACKEND_SERVERS[@]}"; do
    echo "    server app${i} $server:$BACKEND_HTTPS_PORT ssl verify none check cookie app${i}" | sudo tee -a "$HAPROXY_CFG" > /dev/null
    ((i++))
done

# =========================
# Restart HAProxy
# =========================
echo "Restarting HAProxy..."
sudo systemctl restart haproxy
sudo systemctl status haproxy --no-pager

echo "✅ App Load Balancer setup completed successfully!"
