#!/bin/bash
#=========================================
# PostgreSQL Setup Script for Siwapp - Replica 3
# Idempotent - safe to re-run
#=========================================

set -euo pipefail

#-----------[ Configuration Variables ]-----------
HOSTNAME=${1}
PRIMARY_IP=${3}
REPL_USER="replicator"
REPL_PASS="ReplsiwappPass123"
SLOT_NAME="replica3_slot"
#--------------------------------------------------

# Set Hostname
echo "Setting hostname to ${HOSTNAME}..."
sudo hostnamectl set-hostname "${HOSTNAME}"

# Update system packages
echo "Updating system..."
sudo apt update -y

# Install PostgreSQL
echo "Installing PostgreSQL..."
sudo apt install -y postgresql postgresql-contrib

# Find PostgreSQL version and data directory
PG_DIR=$(find /etc/postgresql -maxdepth 1 -type d | grep -E '[0-9]+$')
PG_VER=$(basename "$PG_DIR")
DATA_DIR="/var/lib/postgresql/${PG_VER}/main"
PG_CONF=$(find /etc/postgresql -name "postgresql.conf" | head -1)
PG_HBA=$(find /etc/postgresql -name "pg_hba.conf" | head -1)

# Check if already replicating
IS_REPLICA=false
if systemctl is-active --quiet postgresql; then
  RECOVERY=$(sudo -u postgres psql -tAc "SELECT pg_is_in_recovery();" 2>/dev/null || echo "false")
  if [ "$RECOVERY" = "t" ]; then
    IS_REPLICA=true
  fi
fi

if [ "$IS_REPLICA" = true ]; then
  echo "✅ Already running as replica, skipping pg_basebackup"
else
  echo "Setting up as replica..."

  # Stop PostgreSQL
  echo "Stopping PostgreSQL..."
  sudo systemctl stop postgresql

  # Delete Old Data
  echo "Cleaning old data directory..."
  sudo rm -rf "${DATA_DIR:?}"/*

  # Clone Primary Node Data
  echo "Cloning data from primary (this may take a while)..."
  sudo -u postgres PGPASSWORD="${REPL_PASS}" pg_basebackup \
    -h "${PRIMARY_IP}" \
    -D "${DATA_DIR}" \
    -U "${REPL_USER}" \
    -Fp -Xs -P -R

  # Update Standby Node Config
  echo "Updating standby configuration..."
  sudo tee "${DATA_DIR}/postgresql.auto.conf" >/dev/null <<EOF
primary_conninfo = 'host=${PRIMARY_IP} user=${REPL_USER} password=${REPL_PASS}'
primary_slot_name = '${SLOT_NAME}'
EOF
fi

# Allow external connections (idempotent)
echo "Configuring PostgreSQL to allow remote connections..."

if grep -q "^listen_addresses" "$PG_CONF"; then
  echo "listen_addresses already configured, skipping"
else
  sudo sed -i "s/^#listen_addresses = 'localhost'/listen_addresses = '*'/" "$PG_CONF"
fi

if ! grep -q "host all all 0.0.0.0/0 md5" "$PG_HBA"; then
  echo "host all all 0.0.0.0/0 md5" | sudo tee -a "$PG_HBA" >/dev/null
else
  echo "pg_hba rule already exists, skipping"
fi

# Enable and start PostgreSQL
echo "Starting PostgreSQL..."
sudo systemctl enable --now postgresql

# Verify replication status
echo "Verifying replication status..."
sleep 3
RECOVERY_CHECK=$(sudo -u postgres psql -tAc "SELECT pg_is_in_recovery();" 2>/dev/null || echo "unknown")
if [ "$RECOVERY_CHECK" = "t" ]; then
  echo "✅ PostgreSQL replica setup completed successfully! (Replicating from ${PRIMARY_IP})"
else
  echo "⚠️  PostgreSQL is running but may not be replicating. Check logs:"
  echo "    sudo journalctl -u postgresql --no-pager -n 20"
fi
