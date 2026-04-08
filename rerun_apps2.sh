#!/bin/bash
set -euo pipefail
exec > >(tee -a install_rerun.log) 2>&1

SSH_USER="zoran"
KEY_PATH="~/.ssh/id_ed25519"
REMOTE_SCRIPT_DIR="/tmp"
DB_LB_IP="192.168.3.52"
APP_LB_FQDN="invoice.plslab.net"

APP_HOSTS=("invoice-app1" "invoice-app2" "invoice-app3")
APP_IPS=("192.168.3.53" "192.168.3.54" "192.168.3.55")
APP_LB_HOST="invoice-app-lb"
APP_LB_IP="192.168.3.51"

run_install() {
  local node_ip=$1
  local node_host=$2
  local script_name=$3
  local lb0=${4:-""}
  local lb1=${5:-""}
  local lb2=${6:-""}
  local lb3=${7:-""}

  echo "----------------------------------------"
  echo "ðŸ”¹í´¹ Installing on $node_host ($node_ip) using $script_name"
  echo "----------------------------------------"

  scp -o StrictHostKeyChecking=no -i "$KEY_PATH" "$script_name" "$SSH_USER@$node_ip:$REMOTE_SCRIPT_DIR/" >/dev/null
  ssh -o StrictHostKeyChecking=no -i "$KEY_PATH" "$SSH_USER@$node_ip" \
    "sudo bash $REMOTE_SCRIPT_DIR/$script_name $node_host $node_ip $lb0 $lb1 $lb2 $lb3"
}

# All 3 App Nodes
for i in "${!APP_HOSTS[@]}"; do
  run_install "${APP_IPS[$i]}" "${APP_HOSTS[$i]}" "invoice-app$((i+1)).sh" "$DB_LB_IP"
done

# App Load Balancer
run_install "$APP_LB_IP" "$APP_LB_HOST" "invoice-app-lb.sh" "$APP_LB_FQDN" "${APP_IPS[@]}"

echo "âœ… App installation completed"

echo "All done!"
!
