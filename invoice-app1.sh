#!/bin/bash
#===============================================================================
# Siwapp Installation Script (Elixir version) - App Node 1 (Primary)
# Idempotent - safe to re-run
#===============================================================================

set -e

# ===============================
# Variables
# ===============================
HOSTNAME=${1}
DB_PASSWORD="StrongDBPassword"
DB_HOST=${3}

SSL_CN="${1}.local"
SSL_IP="$(ip route get 8.8.8.8 | awk '{print $7; exit}')"
SSL_DIR="/etc/ssl/siwapp"

HTTP_PORT=8080
HTTPS_PORT=8443

APP_USER="siwapp"
APP_DIR="/var/www/siwapp"
MIX_ENV="prod"
RELEASE_NODE="siwapp"
PHX_HOST="127.0.0.1"
PORT="4000"

# Set Hostname
echo "Setting hostname to ${HOSTNAME}..."
sudo hostnamectl set-hostname "${HOSTNAME}"

# ===============================
# Update & Install Dependencies
# ===============================
echo "Installing dependencies..."
sudo apt update
sudo apt install -y wget gnupg git erlang elixir libpq-dev postgresql-client nginx openssl

# Install Google Chrome (idempotent)
# ===============================
if ! command -v google-chrome &>/dev/null; then
  echo "Installing Google Chrome..."
  sudo rm -f /tmp/google-chrome.deb
  wget -qO /tmp/google-chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
  sudo DEBIAN_FRONTEND=noninteractive dpkg -i /tmp/google-chrome.deb || sudo DEBIAN_FRONTEND=noninteractive apt install -f -y
  rm -f /tmp/google-chrome.deb
else
  echo "Google Chrome already installed, skipping"
fi

# ===============================
# Create App User & Directory (idempotent)
# ===============================
if ! id "$APP_USER" &>/dev/null; then
  echo "Creating user $APP_USER..."
  sudo adduser --disabled-login --gecos 'Siwapp App' "$APP_USER"
else
  echo "User $APP_USER already exists, skipping"
fi

sudo mkdir -p "$APP_DIR"
sudo chown -R "$APP_USER:$APP_USER" "$APP_DIR"

# ===============================
# Clone Siwapp Repo (idempotent)
# ===============================
if [ ! -d "$APP_DIR/.git" ]; then
  echo "Cloning Siwapp repo..."
  sudo -u "$APP_USER" -H bash -c "git clone 'https://github.com/siwapp/siwapp.git' '$APP_DIR' && cd '$APP_DIR' && git checkout 1aed7462f78368c630be3817ddde8f23118c113d"
else
  echo "Siwapp repo already cloned, skipping"
fi

# ===============================
# Configure PDF Options (idempotent)
# ===============================
if ! grep -q "chrome_executable" "$APP_DIR/config/prod.exs" 2>/dev/null; then
  echo "Configuring PDF options..."
  sudo sed -i '/^config :siwapp, *$/{
      N
      s/env: :prod$/env: :prod,/
      a\
  pdf_opts: [\
    no_sandbox: true,\
    discard_stderr: true,\
    chrome_executable: \"/usr/bin/google-chrome\"\
  ]
  }' "$APP_DIR/config/prod.exs"
else
  echo "PDF options already configured, skipping"
fi

# ===============================
# Install & Compile App
# ===============================
echo "Compiling Siwapp..."
sudo -u "$APP_USER" -H bash -c "
export MIX_ENV=$MIX_ENV
export RELEASE_NODE=$RELEASE_NODE
export DATABASE_URL=ecto://$APP_USER:$DB_PASSWORD@$DB_HOST/siwapp_prod
export PHX_HOST=$PHX_HOST
export PORT=$PORT
cd $APP_DIR
mix local.hex --force
mix local.rebar --force
MIX_ENV=$MIX_ENV mix deps.get
MIX_ENV=$MIX_ENV mix deps.compile
MIX_ENV=$MIX_ENV mix assets.deploy
MIX_ENV=$MIX_ENV mix phx.digest
MIX_ENV=$MIX_ENV mix compile
"

# ===============================
# Generate or Reuse SECRET_KEY_BASE
# ===============================
if [ -f /etc/default/siwapp ] && grep -q "SECRET_KEY_BASE=" /etc/default/siwapp; then
  echo "Reusing existing SECRET_KEY_BASE..."
  SECRET_KEY_BASE=$(grep "SECRET_KEY_BASE=" /etc/default/siwapp | cut -d'=' -f2)
else
  echo "Generating new SECRET_KEY_BASE..."
  sudo -u "$APP_USER" -H bash -c "export DATABASE_URL=ecto://$APP_USER:$DB_PASSWORD@$DB_HOST/siwapp_prod && cd $APP_DIR && MIX_ENV=$MIX_ENV mix phx.gen.secret" > /tmp/siwapp_secret
  SECRET_KEY_BASE=$(cat /tmp/siwapp_secret)
  rm -f /tmp/siwapp_secret
fi

# ===============================
# Setup Database & Release (idempotent)
# ===============================
echo "Setting up database and building release..."
sudo -u "$APP_USER" -H bash -c "
export MIX_ENV=$MIX_ENV
export RELEASE_NODE=$RELEASE_NODE
export DATABASE_URL=ecto://$APP_USER:$DB_PASSWORD@$DB_HOST/siwapp_prod
export SECRET_KEY_BASE=$SECRET_KEY_BASE
export PHX_HOST=$PHX_HOST
export PORT=$PORT
cd $APP_DIR
MIX_ENV=$MIX_ENV mix ecto.create 2>/dev/null || echo 'Database already exists, skipping create'
MIX_ENV=$MIX_ENV mix ecto.migrate
MIX_ENV=$MIX_ENV mix release --overwrite
"

# ===============================
# Create Demo Data (idempotent - check if data exists)
# ===============================
DEMO_EXISTS=$(PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $APP_USER -d siwapp_prod -tAc "SELECT COUNT(*) FROM customers;" 2>/dev/null || echo "0")
if [ "$DEMO_EXISTS" = "0" ] || [ "$DEMO_EXISTS" = "" ]; then
  echo "Loading demo data..."
  sudo -u "$APP_USER" -H bash -c "
  export SECRET_KEY_BASE=$SECRET_KEY_BASE
  export DATABASE_URL=ecto://$APP_USER:$DB_PASSWORD@$DB_HOST/siwapp_prod
  cd $APP_DIR
  MIX_ENV=$MIX_ENV mix siwapp.demo force
  "
else
  echo "Demo data already exists ($DEMO_EXISTS customers), skipping"
fi

# ===============================
# Change Favicon (always overwrite - harmless)
# ===============================
echo "Updating favicon..."
sudo -u "$APP_USER" -H bash -c "
wget -q --no-cache -O $APP_DIR/priv/static/favicon.ico https://raw.githubusercontent.com/wajihalsaid/siwapp/refs/heads/main/favicon.ico
wget -q --no-cache -O $APP_DIR/_build/prod/rel/siwapp/lib/phoenix-*/priv/static/favicon.ico https://raw.githubusercontent.com/wajihalsaid/siwapp/refs/heads/main/favicon.ico
wget -q --no-cache -O $APP_DIR/_build/prod/rel/siwapp/lib/siwapp-*/priv/static/favicon.ico https://raw.githubusercontent.com/wajihalsaid/siwapp/refs/heads/main/favicon.ico
wget -q --no-cache -O $APP_DIR/deps/phoenix/priv/static/favicon.ico https://raw.githubusercontent.com/wajihalsaid/siwapp/refs/heads/main/favicon.ico
"

# ===============================
# Environment File (always overwrite)
# ===============================
echo "Writing environment file..."
sudo tee /etc/default/siwapp > /dev/null <<EOF
MIX_ENV=$MIX_ENV
RELEASE_NODE=$RELEASE_NODE
DATABASE_URL=ecto://$APP_USER:$DB_PASSWORD@$DB_HOST/siwapp_prod
SECRET_KEY_BASE=$SECRET_KEY_BASE
PHX_HOST=$PHX_HOST
PORT=$PORT
EOF

# ===============================
# Systemd Service (always overwrite)
# ===============================
echo "Configuring systemd service..."
sudo tee /etc/systemd/system/siwapp.service >/dev/null <<'EOF'
[Unit]
Description=Siwapp Phoenix app (release)
After=network.target

[Service]
User=siwapp
Group=siwapp
EnvironmentFile=/etc/default/siwapp
WorkingDirectory=/var/www/siwapp
ExecStart=/var/www/siwapp/_build/prod/rel/siwapp/bin/siwapp start
ExecStop=/var/www/siwapp/_build/prod/rel/siwapp/bin/siwapp stop
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now siwapp

# ===============================
# SSL Self-Signed Certificate (idempotent)
# ===============================
if [ ! -f "$SSL_DIR/siwapp.crt" ]; then
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
else
  echo "SSL certificate already exists, skipping"
fi

# ===============================
# Server ID (always overwrite)
# ===============================
sudo mkdir -p /var/www/siwapp/assets/custom
sudo tee /var/www/siwapp/assets/custom/backend_id.js > /dev/null <<EOF
document.addEventListener("DOMContentLoaded", function () {
  const host = "${HOSTNAME}";
  const srv = document.cookie
    .split('; ')
    .find(row => row.startsWith('SRV_ID='))
    ?.split('=')[1];
  const label = host || srv;

  if (label) {
    const div = document.createElement("div");
    div.textContent = label;
    div.style.position = "fixed";
    div.style.top = "60px";
    div.style.right = "10px";
    div.style.background = "rgba(0,0,0,0.6)";
    div.style.color = "#fff";
    div.style.padding = "4px 8px";
    div.style.borderRadius = "4px";
    div.style.fontSize = "10px";
    div.style.zIndex = "99999";
    div.style.fontFamily = "Arial, sans-serif";
    document.body.appendChild(div);
  }
});
EOF

# ===============================
# Nginx Reverse Proxy (always overwrite)
# ===============================
echo "Configuring Nginx..."
sudo tee /etc/nginx/sites-available/siwapp.conf > /dev/null <<EOF
server {
    listen ${HTTP_PORT};
    listen [::]:${HTTP_PORT};
    server_name _;

    client_max_body_size 50M;

    location / {
        sub_filter '</body>' '<script src="/assets/custom/backend_id.js"></script></body>';
        sub_filter_once on;
        proxy_pass http://127.0.0.1:${PORT};
        proxy_http_version 1.1;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$http_connection;

        proxy_connect_timeout 60s;
        proxy_send_timeout 120s;
        proxy_read_timeout 300s;
    }

    location /assets/ {
        alias /var/www/siwapp/priv/static/assets/;
        gzip_static on;
        expires max;
        add_header Cache-Control "public";
    }
    location /assets/custom/ {
        alias /var/www/siwapp/assets/custom/;
    }
}

server {
    listen ${HTTPS_PORT} ssl http2;
    listen [::]:${HTTPS_PORT} ssl http2;
    server_name _;

    ssl_certificate ${SSL_DIR}/siwapp.crt;
    ssl_certificate_key ${SSL_DIR}/siwapp.key;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;
    ssl_session_timeout 10m;

    client_max_body_size 50M;
    keepalive_timeout 65;

    location / {
        sub_filter '</body>' '<script src="/assets/custom/backend_id.js"></script></body>';
        sub_filter_once on;
        proxy_pass http://127.0.0.1:${PORT};
        proxy_http_version 1.1;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$http_connection;

        proxy_connect_timeout 60s;
        proxy_send_timeout 120s;
        proxy_read_timeout 300s;
    }

    location /assets/ {
        alias /var/www/siwapp/priv/static/assets/;
        gzip_static on;
        expires max;
        add_header Cache-Control "public";
    }
    location /assets/custom/ {
        alias /var/www/siwapp/assets/custom/;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/siwapp.conf /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx

echo "NGINX configured on ports $HTTP_PORT (HTTP) and $HTTPS_PORT (HTTPS)"
echo "✅ Siwapp App1 installation completed successfully!"
