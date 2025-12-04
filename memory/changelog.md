# Changelog

## [Unreleased]

### Added
- `docker-compose.yaml`: Main Compose file for the stack.
- `scripts/cleanup-swarm.sh`: Script to remove legacy Swarm artifacts.
- `scripts/check-ports.sh`: Utility to check for port conflicts.
- `scripts/verify-qb-wg.sh`: Utility to verify VPN routing for qBittorrent.
- `scripts/validate-ports.sh`: Utility to validate ports from .env.

### Changed
- Migrated from Docker Swarm to Docker Compose.
- Updated `README.md` (Pending review).
- Updated `docs/deployment.md` (Pending review).

### Removed
- Legacy Swarm stack configurations (planned).
