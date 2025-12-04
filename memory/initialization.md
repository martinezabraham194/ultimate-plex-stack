# Initialization

## Project Goal
Migrate the "Ultimate Plex Stack" from Docker Swarm to a simpler Docker Compose deployment, integrating ProtonVPN WireGuard on the host for qBittorrent traffic.

## Context
The project previously used Docker Swarm, which presented challenges with granting `NET_ADMIN` capabilities and routing traffic through a VPN. The new approach uses Docker Compose with `network_mode: host` for qBittorrent, binding it to the host's WireGuard interface (`wg0`).

## Key Files
- `docker-compose.yaml`: The new main Compose file.
- `scripts/cleanup-swarm.sh`: Script to remove Swarm artifacts.
- `scripts/check-ports.sh`: Script to verify host ports are free.
- `scripts/verify-qb-wg.sh`: Script to verify VPN routing.
- `docs/protonvpn-wireguard.md`: Setup guide for ProtonVPN (Missing).

## Assumptions
- User has root/sudo access.
- User has ProtonVPN credentials/config.
- Docker and Docker Compose are installed.
