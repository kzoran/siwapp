#!/usr/bin/env bash
set -e

TARGET="$1"
INSTALL_PATH="/usr/local/bin/login_probe.sh"
LOG_FILE="/var/log/login_probe.log"
CRON_TAG="# LOGIN_PROBE_CRON"
EMAIL="demo@example.com"
PASSWORD="secretsecret"

if [[ -z "$TARGET" ]]; then
  echo "Usage: $0 <IP-or-domain>"
  exit 1
fi

echo "[+] Installing login probe for target: $TARGET"

# -----------------------------
# Create worker script
# -----------------------------
sudo tee "$INSTALL_PATH" > /dev/null <<'EOF'
#!/usr/bin/env bash

TARGET="$1"
EMAIL="demo@example.com"
PASSWORD="secretsecret"
LOG_FILE="/var/log/login_probe.log"

timestamp() {
  date '+%Y-%m-%d %H:%M:%S'
}

log() {
  echo "[$(timestamp)] $1" >> "$LOG_FILE"
}

TMPDIR=$(mktemp -d)
COOKIE_HTTP="$TMPDIR/cookies_http.txt"
COOKIE_HTTPS="$TMPDIR/cookies_https.txt"
LOGIN_HTTP="$TMPDIR/login_http.html"
LOGIN_HTTPS="$TMPDIR/login_https.html"

extract_csrf() {
  grep -oP 'name="_csrf_token"[^>]*value="\K[^"]+' "$1"
}

do_login() {
  local SCHEME="$1"
  local COOKIE="$2"
  local HTML="$3"

  log "[$SCHEME] GET /users/log_in"
  curl -s -k -c "$COOKIE" \
    "${SCHEME}://${TARGET}/users/log_in" \
    -o "$HTML"

  CSRF=$(extract_csrf "$HTML")

  if [[ -z "$CSRF" ]]; then
    log "[$SCHEME] ❌ CSRF extraction failed"
    return
  fi

  log "[$SCHEME] POST /users/log_in"
  STATUS=$(curl -s -k -b "$COOKIE" -c "$COOKIE" \
    -o /dev/null -w "%{http_code}" \
    -X POST "${SCHEME}://${TARGET}/users/log_in" \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    -H "Origin: ${SCHEME}://${TARGET}" \
    --data "_csrf_token=${CSRF}&user[email]=${EMAIL}&user[password]=${PASSWORD}&user[remember_me]=false")

  log "[$SCHEME] Login HTTP status: $STATUS"
}

log "===== Run started ====="

do_login "http"  "$COOKIE_HTTP"  "$LOGIN_HTTP"
do_login "https" "$COOKIE_HTTPS" "$LOGIN_HTTPS"

log "===== Run finished ====="

rm -rf "$TMPDIR"
EOF

sudo chmod +x "$INSTALL_PATH"

# -----------------------------
# Create log file
# -----------------------------
sudo touch "$LOG_FILE"
sudo chmod 644 "$LOG_FILE"

# -----------------------------
# Install cron job
# -----------------------------
echo "[+] Installing cron job (every 1 minute)"

# Read current crontab, remove old LOGIN_PROBE_CRON entry if any, then add new one
# Safe cron install
TMPCRON=$(mktemp)
crontab -l 2>/dev/null > "$TMPCRON" || true
# Remove old entry
grep -v "$CRON_TAG" "$TMPCRON" > "${TMPCRON}.new" || true
echo "$CRON_TAG" >> "${TMPCRON}.new"
echo "* * * * * $INSTALL_PATH $TARGET >> $LOG_FILE 2>&1" >> "${TMPCRON}.new"
crontab "${TMPCRON}.new"
rm -f "$TMPCRON" "${TMPCRON}.new"

# Verify cron job
echo "[+] Cron job installed. Current crontab:"
crontab -l

echo "[+] Installation complete"
echo "[+] Script location : $INSTALL_PATH"
echo "[+] Log file        : $LOG_FILE"
echo "[+] Cron schedule   : Every 5 minutes"
echo
echo "Use: tail -f $LOG_FILE"
