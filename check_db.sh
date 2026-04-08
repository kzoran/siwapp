#!/bin/bash
KEY_PATH="~/.ssh/id_ed25519"
SSH_USER="zoran"

echo "========== DB1 (Primary) =========="
ssh -i "$KEY_PATH" "$SSH_USER@192.168.3.56" "
echo '--- PostgreSQL Status ---'
sudo systemctl is-active postgresql
echo '--- Role: siwapp ---'
sudo -u postgres psql -tAc \"SELECT 1 FROM pg_roles WHERE rolname='siwapp'\" | grep -q 1 && echo 'EXISTS' || echo 'MISSING'
echo '--- Role: replicator ---'
sudo -u postgres psql -tAc \"SELECT 1 FROM pg_roles WHERE rolname='replicator'\" | grep -q 1 && echo 'EXISTS' || echo 'MISSING'
echo '--- Database: siwapp_prod ---'
sudo -u postgres psql -tAc \"SELECT 1 FROM pg_database WHERE datname='siwapp_prod'\" | grep -q 1 && echo 'EXISTS' || echo 'MISSING'
echo '--- Replication Slots ---'
sudo -u postgres psql -tAc \"SELECT slot_name, active FROM pg_replication_slots;\"
echo '--- Connected Replicas ---'
sudo -u postgres psql -tAc \"SELECT client_addr, state FROM pg_stat_replication;\"
"

echo ""
echo "========== DB2 (Replica) =========="
ssh -i "$KEY_PATH" "$SSH_USER@192.168.3.50" "
echo '--- PostgreSQL Status ---'
sudo systemctl is-active postgresql
echo '--- Is Replica? ---'
sudo -u postgres psql -tAc \"SELECT pg_is_in_recovery();\"
"

echo ""
echo "========== DB3 (Replica) =========="
ssh -i "$KEY_PATH" "$SSH_USER@192.168.3.76" "
echo '--- PostgreSQL Status ---'
sudo systemctl is-active postgresql
echo '--- Is Replica? ---'
sudo -u postgres psql -tAc \"SELECT pg_is_in_recovery();\"
"

echo ""
echo "========== DB-LB (HAProxy) =========="
ssh -i "$KEY_PATH" "$SSH_USER@192.168.3.52" "
echo '--- HAProxy Status ---'
sudo systemctl is-active haproxy
echo '--- Health Check Timer ---'
sudo systemctl is-active pg_role_check.timer
echo '--- Test Connection Through LB ---'
PGPASSWORD=StrongDBPassword psql -h 127.0.0.1 -U siwapp -d siwapp_prod -tAc 'SELECT 1;' 2>/dev/null && echo 'LB CONNECTION: OK' || echo 'LB CONNECTION: FAILED'
"
