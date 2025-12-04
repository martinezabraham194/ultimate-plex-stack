#!/usr/bin/env bash
set -euo pipefail

# scripts/validate-ports.sh
# Loads .env if present and checks a set of host ports for LISTEN conflicts using `ss`.
# Exits with:
#  0 - no conflicts
#  2 - one or more conflicts detected
#  1 - fatal error (docker/ss missing, etc)
#
# Usage:
#   ./scripts/validate-ports.sh
#
# Notes:
# - Ensure this script is executable: chmod +x scripts/validate-ports.sh
# - The script will read ports from .env if present. If .env is missing it uses default variable names only.

# load .env if exists in repository root
if [ -f .env ]; then
  # shellcheck disable=SC1091
  set -o allexport; source .env; set +o allexport
fi

command -v ss >/dev/null 2>&1 || { echo "ss (iproute2) required but not found"; exit 1; }

PORT_VARS=(
  PLEX_PORT RADARR_PORT SONARR_PORT READARR_PORT LIDARR_PORT PROWLARR_PORT
  OVERSEERR_PORT FLARESOLVERR_PORT TAUTULLI_PORT TDARR_WEB_PORT TDARR_SERVER_PORT
  BAZARR_PORT DOZZLE_PORT WIZARR_PORT CROSSSEED_PORT QB_WEBUI_PORT QB_TORRENT_PORT
)

conflicts=0

echo "Validating host ports..."
for var in "${PORT_VARS[@]}"; do
  # indirect expansion - if variable not set, skip
  port="${!var:-}"
  if [ -z "$port" ]; then
    continue
  fi

  # Check if any listener is bound to the port (IPv4 or IPv6)
  if ss -ltn 2>/dev/null | awk '{print $4}' | grep -E "(:|\\.)${port}$" >/dev/null 2>&1; then
    echo "CONFLICT: port ${port} (env ${var}) appears to be in use"
    conflicts=$((conflicts + 1))
  else
    echo "OK: port ${port} (env ${var}) is free"
  fi
done

if [ "$conflicts" -gt 0 ]; then
  echo
  echo "Found ${conflicts} conflicting port(s). Resolve conflicts or change ports in .env before deploying."
  exit 2
fi

echo
echo "No port conflicts detected."
exit 0
