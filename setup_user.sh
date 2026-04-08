#!/bin/bash

# Define your VMs (replace with actual IPs/hostnames)
SERVERS=(
  "192.168.3.51"
  "192.168.3.52"
  "192.168.3.53"
  "192.168.3.54"
  "192.168.3.55"
  "192.168.3.56"
  "192.168.3.50"
  "192.168.3.76"
)

USERNAME="zoran"
SSH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBXq43kjgI8SAC4pdMwLHkDMjvkGz7wAnk+IaGDiIVqV siwapp-deploy"

for SERVER in "${SERVERS[@]}"; do
  echo "Setting up $SERVER..."
  ssh root@$SERVER <<EOF
    # Create user
    useradd -m -s /bin/bash $USERNAME
    
    # Set up SSH directory and key
    mkdir -p /home/$USERNAME/.ssh
    echo "$SSH_KEY" >> /home/$USERNAME/.ssh/authorized_keys
    
    # Set correct permissions
    chmod 700 /home/$USERNAME/.ssh
    chmod 600 /home/$USERNAME/.ssh/authorized_keys
    chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh
    
    # (Optional) Add user to sudo group
    usermod -aG sudo $USERNAME
    
    echo "Done on $SERVER"
EOF
done
