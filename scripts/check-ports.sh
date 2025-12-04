#!/usr/bin/env bash
# check-ports.sh
# Verify required host TCP ports are free (listens) before bringing up docker-compose.
#
# Usage:
#   sudo ./scripts/check-ports.sh            # uses built-in port set
#   sudo ./scripts/check-ports.sh 31808 8694 # supply custom ports
#
# Notes:
# - Uses `ss` to detect LISTEN sockets. Requires ss (iproute2) available.
# - Run as root or a user with permission to see process info for accurate results.

set -euo pipefail

# Default ports to check (based on implementation plan)
DEFAULT_PORTS=(31808 8694 32400 7878 8989 9696 5055 8265 8266 32001 32002 6767 5690 32700)

PORTS=()
if [ "$#" -gt 0 ]; then
  PORTS=("$@")
else
  PORTS=("${DEFAULT_PORTS[@]}")
fi

SS_OUTPUT=$(ss -ltnp 2>/dev/null) || SS_OUTPUT=""
if [ -z "$SS_OUTPUT" ]; then
  echo "[WARN] 'ss' returned no output. Ensure iproute2 is installed and you have permission to run ss."
fi

check_port() {
  local p=$1
  # Try ss socket filter first (works on modern ss): ss -ltn "(sport = :$p)"
  if ss -ltn "(sport = :$p)" >/dev/null 2>&1; then
    # show details
    ss -ltnp "(sport = :$p)" 2>/dev/null | sed 's/^/    /'
    return 0
  fi

  # Fallback: grep in cached ss output
  if printf "%s\n" "$SS_OUTPUT" | grep -E "[:.]$p(\s|$)" >/dev/null 2>&1; then
    printf "    %s\n" "$(printf "%s\n" "$SS_OUTPUT" | grep -E "[:.]$p(\s|$)" | sed 's/^/    /')"
    return 0
  fi

  return 1
}

echo "Checking ports: ${PORTS[*]}"
echo

FOUND=0
for p in "${PORTS[@]}"; do
  if check_port "$p"; then
    echo "[IN USE] Port $p is LISTENING"
    FOUND=1
  else
    echo "[FREE]   Port $p"
  fi
done

if [ "$FOUND" -eq 1 ]; then
  echo
  echo "[ERROR] One or more required ports are in use. Stop the conflicting services before proceeding."
  exit 2
else
  echo
  echo "[OK] All checked ports are free."
  exit 0
fi
