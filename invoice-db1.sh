#!/bin/bash
#=========================================
# PostgreSQL Setup Script for Siwapp - Primary Node
# Idempotent - safe to re-run
#=========================================

set -euo pipefail

#-----------[ Configuration Variables ]-----------
HOSTNAME=${1}
DB_USER="siwapp"
DB_PASS="StrongDBPassword"
DB_NAME="siwapp_prod"
REPL_USER="replicator"
REPL_PASS="ReplsiwappPass123"
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

# Enable and start PostgreSQL
sudo systemctl enable --now postgresql

# Create database role and database (idempotent)
echo "Creating PostgreSQL role and database..."

sudo -u postgres psql -c "
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${DB_USER}') THEN
    CREATE ROLE ${DB_USER} WITH LOGIN PASSWORD '${DB_PASS}';
    RAISE NOTICE 'Role ${DB_USER} created';
  ELSE
    RAISE NOTICE 'Role ${DB_USER} already exists, skipping';
  END IF;
END
\$\$;"

sudo -u postgres psql -c "
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${REPL_USER}') THEN
    CREATE ROLE ${REPL_USER} WITH REPLICATION LOGIN PASSWORD '${REPL_PASS}';
    RAISE NOTICE 'Role ${REPL_USER} created';
  ELSE
    RAISE NOTICE 'Role ${REPL_USER} already exists, skipping';
  END IF;
END
\$\$;"

DB_EXISTS=$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname = '${DB_NAME}'")
if [ "$DB_EXISTS" != "1" ]; then
  sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER} ENCODING 'UTF8';"
  echo "Database ${DB_NAME} created"
else
  echo "Database ${DB_NAME} already exists, skipping"
fi

sudo -u postgres psql -c "
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_replication_slots WHERE slot_name = 'replica2_slot') THEN
    PERFORM pg_create_physical_replication_slot('replica2_slot');
    RAISE NOTICE 'Replication slot replica2_slot created';
  ELSE
    RAISE NOTICE 'Replication slot replica2_slot already exists, skipping';
  END IF;
END
\$\$;"

sudo -u postgres psql -c "
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_replication_slots WHERE slot_name = 'replica3_slot') THEN
    PERFORM pg_create_physical_replication_slot('replica3_slot');
    RAISE NOTICE 'Replication slot replica3_slot already exists, skipping';
  ELSE
    RAISE NOTICE 'Replication slot replica3_slot already exists, skipping';
  END IF;
END
\$\$;"

# Allow external connections (idempotent)
echo "Configuring PostgreSQL to allow remote connections..."

PG_CONF=$(find /etc/postgresql -name "postgresql.conf" | head -1)
PG_HBA=$(find /etc/postgresql -name "pg_hba.conf" | head -1)

# listen_addresses
if grep -q "^listen_addresses" "$PG_CONF"; then
  echo "listen_addresses already configured, skipping"
else
  sudo sed -i "s/^#listen_addresses = 'localhost'/listen_addresses = '*'/" "$PG_CONF"
fi

# pg_hba: allow all connections
if ! grep -q "host all all 0.0.0.0/0 md5" "$PG_HBA"; then
  echo "host all all 0.0.0.0/0 md5" | sudo tee -a "$PG_HBA" >/dev/null
else
  echo "pg_hba rule for all connections already exists, skipping"
fi

# pg_hba: allow replication
if ! grep -q "host replication all 0.0.0.0/0 md5" "$PG_HBA"; then
  echo "host replication all 0.0.0.0/0 md5" | sudo tee -a "$PG_HBA" >/dev/null
else
  echo "pg_hba replication rule already exists, skipping"
fi

# Configure Replication (idempotent)
if ! grep -q "^wal_level = replica" "$PG_CONF"; then
  sudo tee -a "$PG_CONF" >/dev/null <<EOF
wal_level = replica
max_wal_senders = 10
max_replication_slots = 10
EOF
else
  echo "Replication settings already configured, skipping"
fi

# Restart PostgreSQL
echo "Restarting PostgreSQL service..."
sudo systemctl restart postgresql

echo "✅ PostgreSQL setup completed successfully!"
