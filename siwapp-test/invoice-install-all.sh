#!/bin/bash
set -euo pipefail


# Adding this line to log everything
exec > >(tee -a install.log) 2>&1

# ===============================
# Global Configuration
# ===============================
SSH_USER="zoran"          # Change to your SSH user
KEY_PATH="~/.ssh/id_ed25519"   # SSH private key path
REMOTE_SCRIPT_DIR="/tmp"   # Remote location to copy installation scripts

# ===============================
# Node Variables
# ===============================

# --- Database Nodes ---
DB_LB_HOST="invoice-test-db-lb"
DB_LB_IP="192.168.3.86"

DB_HOSTS=("invoice-test-db1" "invoice-test-db2" "invoice-test-db3")
DB_IPS=("192.168.3.82" "192.168.3.83" "192.168.3.84")

# --- Application Nodes ---
APP_LB_HOST="invoice-test-app-lb"
APP_LB_IP="192.168.3.79"
APP_LB_FQDN="invoice-test.plslab.net"  # FQDN only for app-lb

APP_HOSTS=("invoice-test-app1" "invoice-test-app2" "invoice-test-app3")
APP_IPS=("192.168.3.85" "192.168.3.80" "192.168.3.81")

# ===============================
# Function to run remote installation
# ===============================
run_install() {
  local node_ip=$1
  local node_host=$2
  local script_name=$3
  local lb0=${4:-""}
  local lb1=${5:-""}
  local lb2=${6:-""}
  local lb3=${7:-""}

  echo "----------------------------------------"
  echo "🔹 Installing on $node_host ($node_ip) using $script_name"
  echo "----------------------------------------"

  # Copy script
  scp -o StrictHostKeyChecking=no -i "$KEY_PATH" "$script_name" "$SSH_USER@$node_ip:$REMOTE_SCRIPT_DIR/" >/dev/null

  # Run remotely
    ssh -o StrictHostKeyChecking=no -i "$KEY_PATH" "$SSH_USER@$node_ip" "sudo bash $REMOTE_SCRIPT_DIR/$script_name $node_host $node_ip $lb0 $lb1 $lb2 $lb3"
}

# ===============================
# Execution Order
# ===============================

# 1. Database Nodes
for i in "${!DB_HOSTS[@]}"; do
  run_install "${DB_IPS[i]}" "${DB_HOSTS[$i]}" "invoice-db$((i+1)).sh" "${DB_IPS[0]}"
done

# 2. Database Load Balancer
run_install "$DB_LB_IP" "$DB_LB_HOST" "invoice-db-lb.sh" "${DB_IPS[0]}" "${DB_IPS[1]}" "${DB_IPS[2]}"

# 3. Application Nodes
for i in "${!APP_HOSTS[@]}"; do
  run_install "${APP_IPS[$i]}" "${APP_HOSTS[$i]}" "invoice-app$((i+1)).sh" "$DB_LB_IP"
done

# 4. Application Load Balancer (requires FQDN)
run_install "$APP_LB_IP" "$APP_LB_HOST" "invoice-app-lb.sh" "$APP_LB_FQDN" "${APP_IPS[@]}"

echo "✅ All installations completed successfully!"
