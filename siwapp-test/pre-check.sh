#!/bin/bash
# pre-check.sh ‚Äî Verify all hosts are ready for SIWAPP install

KEY_PATH="~/.ssh/id_ed25519"
SSH_USER="zoran"

ALL_IPS=(
  "192.168.3.82"
  "192.168.3.83"
  "192.168.3.84"
  "192.168.3.86"
  "192.168.3.85"
  "192.168.3.80"
  "192.168.3.81"
  "192.168.3.79"
)

ALL_HOSTS=(
  "invoice-test-db1"
  "invoice-test-db2"
  "invoice-test-db3"
  "invoice-test-db-lb"
  "invoice-test-app1"
  "invoice-test-app2"
  "invoice-test-app3"
  "invoice-test-app-lb"
)

PASS=0
FAIL=0

for i in "${!ALL_IPS[@]}"; do
  IP="${ALL_IPS[$i]}"
  HOST="${ALL_HOSTS[$i]}"

  echo "üîπÌ¥π Checking $HOST ($IP)..."

  # SSH access
  ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i "$KEY_PATH" "$SSH_USER@$IP" "
    echo \"  SSH:       OK\"
    sudo whoami >/dev/null 2>&1 && echo '  Sudo:      OK' || echo '  Sudo:      FAIL'
    env | grep -qi http_proxy && echo '  Proxy:     OK' || echo '  Proxy:     MISSING'
    python3 --version >/dev/null 2>&1 && echo '  Python3:   OK' || echo '  Python3:   MISSING'
    hostname
  " 2>/dev/null

  if [ $? -eq 0 ]; then
    ((PASS++))
  else
    echo "  ‚ùå UNREACHABLE"
    ((FAIL++))
  fi
  echo ""
done

echo "================================="
echo "Results: $PASS passed, $FAIL failed out of ${#ALL_IPS[@]} hosts"
if [ $FAIL -eq 0 ]; then
  echo "‚úÖ All hosts ready for install!"
else
  echo "‚ùå Fix failed hosts before proceeding"
fi
