# Decisions

## 2025-12-04: Migrate to Docker Compose
- **Decision**: Replace Docker Swarm with Docker Compose.
- **Rationale**: Swarm cannot reliably grant `NET_ADMIN` capabilities via stack deploy, complicating VPN setup. Running VPN on the host and using `network_mode: host` for qBittorrent simplifies routing and permissions.
- **Status**: Implemented.

## 2025-12-04: Host-based WireGuard
- **Decision**: Run WireGuard on the host (`wg0`) instead of a sidecar container.
- **Rationale**: Simplifies container networking and avoids complex routing tables within containers. qBittorrent binds directly to the VPN interface.
- **Status**: Implemented.
