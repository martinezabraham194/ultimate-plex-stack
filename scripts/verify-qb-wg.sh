#!/usr/bin/env bash
# verify-qb-wg.sh
# Validate qBittorrent egress when using either a host WireGuard interface or gluetun container.
#
# Usage:
#   sudo ./scripts/verify-qb-wg.sh                # reads .env if present
#   sudo ./scripts/verify-qb-wg.sh wg0 qbittorrent 31808
#
# This script:
#  - Detects host WG interface (WG_INTERFACE) and queries external IP via that interface
#  - Detects a running 'gluetun' container and queries external IP from inside it
#  - Checks qBittorrent container presence and network mode
#  - Attempts WebUI checks from host and from inside gluetun (when present)
#
# Exit codes:
#  0 = checks completed (may contain WARNs)
#  non-zero = fatal error (e.g., missing WG interface when expecting host WG)

set -euo pipefail

# Load .env if available (silently)
ENV_FILE=".env"
if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1091
  source "$ENV_FILE"
fi

WG_INTERFACE="${1:-${WG_INTERFACE:-wg0}}"
QB_CONTAINER_NAME="${2:-${QB_CONTAINER_NAME:-qbittorrent}}"
QB_WEBUI_PORT="${3:-${QB_WEBUI_PORT:-31808}}"
QB_TORRENT_PORT="${QB_TORRENT_PORT:-8694}"

DOCKER_CMD="${DOCKER_CMD:-docker}"
CURL="${CURL:-curl}"

info() { printf "\e[34m[INFO]\e[0m %s\n" "$*"; }
warn() { printf "\e[33m[WARN]\e[0m %s\n" "$*"; }
err()  { printf "\e[31m[ERROR]\e[0m %s\n" "$*"; }

echo
info "Verifying qBittorrent egress (host WG or gluetun container)"
echo

# Host WG checks (best-effort) ---------------------------------------------
if ip link show dev "$WG_INTERFACE" >/dev/null 2>&1; then
  info "WireGuard interface '$WG_INTERFACE' exists on host"
  WG_IP="$(ip -4 -o addr show dev "$WG_INTERFACE" 2>/dev/null | awk '{print $4}' | cut -d'/' -f1 || true)"
  if [ -n "$WG_IP" ]; then
    info "IP on $WG_INTERFACE: $WG_IP"
  else
    warn "No IPv4 address found on $WG_INTERFACE"
  fi

  if command -v $CURL >/dev/null 2>&1; then
    set +e
    WG_EXT_IP="$($CURL --interface "$WG_INTERFACE" -sS --max-time 10 https://ipinfo.io/ip 2>/dev/null || true)"
    WG_CURL_EXIT=$?
    set -e
    if [ -n "$WG_EXT_IP" ]; then
      info "External IP seen via host $WG_INTERFACE: $WG_EXT_IP"
    else
      warn "Failed to get external IP via host $WG_INTERFACE (curl exit $WG_CURL_EXIT)"
    fi
  else
    warn "curl not found on host; cannot query external IP via host WG"
  fi
else
  warn "Host WG interface '$WG_INTERFACE' not present"
fi

# Detect gluetun container (if using VPN inside container) ------------------
GLUETUN_PRESENT=0
GLUETUN_EXT_IP=""
if $DOCKER_CMD ps --format '{{.Names}}' | grep -xq gluetun >/dev/null 2>&1; then
  GLUETUN_PRESENT=1
  info "Found gluetun container"
  # try to get external IP from inside gluetun
  if $DOCKER_CMD exec gluetun sh -c 'command -v curl >/dev/null 2>&1' >/dev/null 2>&1; then
    set +e
    GLUETUN_EXT_IP="$($DOCKER_CMD exec gluetun curl -sS --max-time 10 https://ipinfo.io/ip 2>/dev/null || true)"
    GLUETUN_CURL_EXIT=$?
    set -e
    if [ -n "$GLUETUN_EXT_IP" ]; then
      info "External IP seen from inside gluetun: $GLUETUN_EXT_IP"
    else
      warn "Failed to get external IP from gluetun (docker exec curl exit $GLUETUN_CURL_EXIT)"
    fi
  else
    warn "curl not available inside gluetun container; attempting to read /tmp/gluetun/ip as fallback"
    set +e
    GLUETUN_EXT_IP="$($DOCKER_CMD exec gluetun sh -c 'cat /tmp/gluetun/ip 2>/dev/null || true' 2>/dev/null || true)"
    GLUETUN_CAT_EXIT=$?
    set -e
    if [ -n "$GLUETUN_EXT_IP" ]; then
      info "External IP read from /tmp/gluetun/ip inside gluetun: $GLUETUN_EXT_IP"
    else
      warn "Unable to determine gluetun external IP: curl missing and /tmp/gluetun/ip not present (cat exit $GLUETUN_CAT_EXIT)"
    fi
  fi
else
  info "No gluetun container found"
fi

# qBittorrent container presence -------------------------------------------
info "Looking for qBittorrent container matching name '$QB_CONTAINER_NAME'..."
QB_FULL_NAME=""
if $DOCKER_CMD ps --format '{{.Names}}' | grep -Ei "$QB_CONTAINER_NAME" >/dev/null 2>&1; then
  QB_FULL_NAME="$($DOCKER_CMD ps --format '{{.Names}}' | grep -Ei "$QB_CONTAINER_NAME" | head -n1)"
  info "Found container: $QB_FULL_NAME"
else
  warn "No running container matching '$QB_CONTAINER_NAME' found. Ensure qBittorrent container is running."
fi

# Network mode check for qBittorrent (best-effort) -------------------------
if [ -n "$QB_FULL_NAME" ]; then
  NETMODE="$($DOCKER_CMD inspect --format '{{.HostConfig.NetworkMode}}' "$QB_FULL_NAME" 2>/dev/null || true)"
  info "qBittorrent container network mode: ${NETMODE:-unknown}"
  if [ "$NETMODE" = "service:gluetun" ] || printf "%s\n" "$NETMODE" | grep -q gluetun; then
    info "qBittorrent is sharing network with gluetun (service:gluetun)"
  fi
fi

# Host-level socket checks -------------------------------------------------
info "Checking host listening sockets for WebUI port $QB_WEBUI_PORT and torrent port $QB_TORRENT_PORT"
if ss -ltn "(sport = :$QB_WEBUI_PORT)" >/dev/null 2>&1; then
  ss -ltnp "(sport = :$QB_WEBUI_PORT)" 2>/dev/null | sed 's/^/    /'
  info "Host is listening on WebUI port $QB_WEBUI_PORT"
else
  info "No LISTEN socket found on WebUI port $QB_WEBUI_PORT (host)."
fi

if ss -ltn "(sport = :$QB_TORRENT_PORT)" >/dev/null 2>&1; then
  ss -ltnp "(sport = :$QB_TORRENT_PORT)" 2>/dev/null | sed 's/^/    /'
  info "Host is listening on torrent port $QB_TORRENT_PORT"
else
  info "No LISTEN socket found on torrent port $QB_TORRENT_PORT (host)."
fi

# HTTP checks ---------------------------------------------------------------
info "Attempting HTTP GET http://localhost:$QB_WEBUI_PORT"
set +e
$CURL -sS --max-time 8 "http://localhost:$QB_WEBUI_PORT" -I | sed -n '1,5p'
CURL_EXIT=$?
set -e
if [ "$CURL_EXIT" -eq 0 ]; then
  info "HTTP request to localhost:$QB_WEBUI_PORT returned successfully (exit $CURL_EXIT)"
else
  warn "HTTP request to localhost:$QB_WEBUI_PORT failed (curl exit $CURL_EXIT)"
fi

# If gluetun present, try accessing WebUI from inside gluetun container
if [ "$GLUETUN_PRESENT" -eq 1 ]; then
  info "Attempting HTTP GET from inside gluetun to 127.0.0.1:$QB_WEBUI_PORT"
  set +e
  $DOCKER_CMD exec gluetun sh -c "$CURL -sS --max-time 8 http://127.0.0.1:$QB_WEBUI_PORT -I" | sed -n '1,5p'
  GLUETUN_WEB_EXIT=$?
  set -e
  if [ "$GLUETUN_WEB_EXIT" -eq 0 ]; then
    info "HTTP request from inside gluetun to qBittorrent WebUI returned successfully (exit $GLUETUN_WEB_EXIT)"
  else
    warn "HTTP request from inside gluetun failed (exit $GLUETUN_WEB_EXIT). qBittorrent may not be up or bound to expected port."
  fi
fi

echo
info "Summary:"
if [ -n "${WG_IP:-}" ] && [ -n "${WG_EXT_IP:-}" ]; then
  info "Host WireGuard active; external IP via host WG: ${WG_EXT_IP:-unknown}"
fi
if [ "$GLUETUN_PRESENT" -eq 1 ]; then
  info "Gluetun external IP: ${GLUETUN_EXT_IP:-unknown}"
fi

if [ -n "$QB_FULL_NAME" ]; then
  info "qBittorrent container: $QB_FULL_NAME"
else
  warn "qBittorrent container not detected"
fi

info "If you need to test external torrent port reachability, use a remote testing host or online TCP port check (note: ProtonVPN forwarded ports depend on your plan)."

exit 0
