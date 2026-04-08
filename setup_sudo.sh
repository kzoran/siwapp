#!/bin/bash
set -euo pipefail

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

echo "Enter sudo password for user '$SSH_USER':"
read -s SUDO_PASS

for IP in "${ALL_IPS[@]}"; do
  echo "üîπÌ¥π Configuring passwordless sudo on $IP..."

  ssh -o StrictHostKeyChecking=no -i "$KEY_PATH" "$SSH_USER@$IP" \
    "echo '${SUDO_PASS}' | sudo --stdin bash -c 'echo \"${SSH_USER} ALL=(ALL) NOPASSWD: ALL\" > /etc/sudoers.d/${SSH_USER} && chmod 440 /etc/sudoers.d/${SSH_USER}'"

  if [ $? -eq 0 ]; then
    echo "  ‚úÖ Done on $IP"
  else
    echo "  ‚ùå Failed on $IP"
  fi
done

echo ""
echo "‚úÖ All VMs configured! You can now run your main install script.
