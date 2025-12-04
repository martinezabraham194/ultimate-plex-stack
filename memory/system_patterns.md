# System Patterns

## Architecture
- **Orchestration**: Docker Compose.
- **Networking**:
    - Most services use the default bridge network.
    - **qBittorrent**: Uses `network_mode: host` to bind directly to the host's WireGuard interface (`wg0`) for VPN tunneling.
- **VPN**: ProtonVPN WireGuard running on the host system.

## Components
- **Media Server**: Plex.
- **Arr Stack**: Radarr, Sonarr, Prowlarr, Readarr, Lidarr, Bazarr.
- **Downloaders**: qBittorrent.
- **Utilities**: Overseerr, Tautulli, Tdarr, Flaresolverr, Dozzle, Wizarr.

## Patterns
- **Host Networking for VPN**: Bypassing container isolation for specific services (qBittorrent) to leverage host-level VPN routing.
- **Script-based Verification**: Using shell scripts (`check-ports.sh`, `verify-qb-wg.sh`) for pre-flight checks and runtime verification.
