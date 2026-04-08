#!/bin/bash

KEY_PATH="~/.ssh/id_ed25519"
SSH_USER="zoran"

ALL_IPS=(
  "192.168.3.52"
  "192.168.3.56"
  "192.168.3.50"
  "192.168.3.76"
  "192.168.3.53"
  "192.168.3.54"
  "192.168.3.55"
  "192.168.3.51"
)

ALL_HOSTS=(
  "invoice-db-lb"
  "invoice-db1"
  "invoice-db2"
  "invoice-db3"
  "invoice-app1"
  "invoice-app2"
  "invoice-app3"
  "invoice-app-lb"
)

for i in "${!ALL_IPS[@]}"; do
  echo "ðŸ”¹í´¹ Checking ${ALL_HOSTS[$i]} (${ALL_IPS[$i]})..."
  ssh -o StrictHostKeyChecking=no -i "$KEY_PATH" "$SSH_USER@${ALL_IPS[$i]}" \
    "which apt-key 2>/dev/null || echo 'apt-key NOT found'; \
     dpkg -l | grep -E 'mariadb|mysql|postgres|nginx|haproxy|php' 2>/dev/null | awk '{print \$2}' || echo 'No relevant packages'"
  echo ""
done
