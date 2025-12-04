#!/bin/sh
# scripts/gluetun-port-forward.sh
# Robust POSIX helper for qmcgaw/gluetun VPN_PORT_FORWARDING_UP_COMMAND
# Usage: /gluetun/gluetun-port-forward.sh 45357
# Exits 0 always to avoid gluetun treating failures as fatal.

PORT="${1:-}"
HOST="127.0.0.1:31808"
COOKIE="/tmp/qb_cookie"

if [ -z "$PORT" ]; then
  echo "No port provided; exiting 0"
  exit 0
fi

attempt=1
max_attempts=24

while [ "$attempt" -le "$max_attempts" ]; do
  echo "pf-helper: attempt ${attempt} to apply port ${PORT}"

  # Try unauthenticated first (form field expected by qBittorrent)
  HTTP=$(wget --server-response --post-data="json={\"listen_port\":${PORT}}" -O /dev/null "http://${HOST}/api/v2/app/setPreferences" 2>&1 | awk '/HTTP\/[0-9.]+/ {print $2; exit}' || echo "000")
  echo "pf-helper: unauthenticated response: ${HTTP}"

  if [ "$HTTP" = "200" ] || [ "$HTTP" = "204" ]; then
    echo "Port ${PORT} applied (unauthenticated) on attempt ${attempt}"
    exit 0
  fi

  # If forbidden and credentials provided, attempt login then authenticated request
  if [ "$HTTP" = "403" ] && [ -n "${WEBUI_USER:-}" ]; then
    echo "pf-helper: performing login attempt"
    wget -q --save-cookies "$COOKIE" --keep-session-cookies --post-data="username=${WEBUI_USER}&password=${WEBUI_PASS}" "http://${HOST}/api/v2/auth/login" -O /dev/null 2>/dev/null || true

    # Authenticated request using saved cookie
    HTTP2=$(wget --server-response --post-data="json={\"listen_port\":${PORT}}" --load-cookies="$COOKIE" -O /dev/null "http://${HOST}/api/v2/app/setPreferences" 2>&1 | awk '/HTTP\/[0-9.]+/ {print $2; exit}' || echo "000")
    echo "pf-helper: authenticated response: ${HTTP2}"
    if [ "$HTTP2" = "200" ] || [ "$HTTP2" = "204" ]; then
      echo "Port ${PORT} applied (authenticated) on attempt ${attempt}"
      exit 0
    fi
  fi

  sleep 5
  attempt=$((attempt + 1))
done

echo "Failed to apply port ${PORT} after ${max_attempts} attempts; exiting 0 to keep gluetun running."
exit 0
