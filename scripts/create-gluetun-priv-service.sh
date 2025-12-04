#!/usr/bin/env bash
set -euo pipefail

# Helper: create a privileged gluetun service on a Docker manager node.
# Usage: bash scripts/create-gluetun-priv-service.sh
# Notes:
# - Must be run on a Docker manager with access to the swarm and Docker CLI.
# - Requires Docker secrets 'proton_user' and 'proton_pass' to exist in the swarm.
# - This creates a service with NET_ADMIN and binds /dev/net/tun; it's a supported
#   approach because `docker stack deploy` cannot grant capabilities or device binds.
#
# Review the generated `docker service create` command before running in production.

# Load .env if present (so variables like BASE_PATH, TZ, PROTONVPN_REGION are available)
if [ -f .env ]; then
  # shellcheck source=/dev/null
  set -a
  . .env
  set +a
fi

# Basic checks
if ! docker node ls >/dev/null 2>&1; then
  echo "Error: Docker CLI cannot access the swarm. Run this on a manager node." >&2
  exit 1
fi

if [ -z "${BASE_PATH:-}" ]; then
  echo "Warning: BASE_PATH not set in .env. Defaulting to ./ (current dir)." >&2
  BASE_PATH="${BASE_PATH:-.}"
fi

echo "Creating privileged gluetun service 'gluetun-priv'..."
echo "Command preview:"
echo "docker service create --name gluetun-priv --replicas 1 --cap-add NET_ADMIN \\"
echo "  --mount type=bind,src=\"${BASE_PATH}/gluetun\",dst=/gluetun \\"
echo "  --mount type=bind,src=/dev/net/tun,dst=/dev/net/tun \\"
echo "  --env TZ=\"${TZ:-UTC}\" --env VPNSP=protonvpn --env REGION=\"${PROTONVPN_REGION:-}\" \\"
echo "  --secret proton_user --secret proton_pass \\"
echo "  --publish published=31888,target=8888,mode=host \\"
echo "  qmcgaw/gluetun:latest"
echo

read -r -p "Proceed to create the service? [y/N] " confirm
if [[ "${confirm,,}" != "y" ]]; then
  echo "Aborting."
  exit 0
fi

docker service create \
  --name gluetun-priv \
  --replicas 1 \
  --cap-add NET_ADMIN \
  --mount type=bind,src="${BASE_PATH}/gluetun",dst=/gluetun \
  --mount type=bind,src=/dev/net/tun,dst=/dev/net/tun \
  --env TZ="${TZ:-UTC}" \
  --env VPNSP=protonvpn \
  --env REGION="${PROTONVPN_REGION:-}" \
  --secret proton_user \
  --secret proton_pass \
  --publish published=31888,target=8888,mode=host \
  qmcgaw/gluetun:latest

echo
echo "Done. Check status with:"
echo "  docker service ps --no-trunc gluetun-priv"
echo "  docker service logs --tail 200 gluetun-priv"
