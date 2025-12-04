# Deployment Guide — Docker Compose (Ultimate Plex Stack)

This document describes steps to prepare the host, configure ProtonVPN WireGuard, and deploy the stack using Docker Compose.

## Prerequisites
- Docker Engine installed (v20.10+) with `docker compose` plugin.
- Root/sudo access on the host.
- ProtonVPN account (for WireGuard config).
- `wireguard-tools` installed on the host.

## 1. Prepare Environment
1.  Copy `.env.example` to `.env`:
    ```bash
    cp .env.example .env
    ```
2.  Edit `.env` with your specific values:
    - `PUID`/`PGID`: User/Group ID for file permissions.
    - `BASE_PATH`: Config directory path.
    - `MEDIA_SHARE`: Media directory path.
    - `PROTON_WG_CONFIG_PATH`: Path to your WireGuard config (e.g., `/etc/wireguard/wg0.conf`).
    - `WG_INTERFACE`: WireGuard interface name (default: `wg0`).

## 2. Setup Directories
Create the necessary directories and set permissions:
```bash
mkdir -p "${BASE_PATH}/"{plex,radarr,sonarr,readarr,lidarr,prowlarr,overseerr,tautulli,qbittorrent,tdarr,autobrr,bazarr,plex-meta-manager,recyclarr,wizarr,cross-seed}
mkdir -p "${MEDIA_SHARE}/"{media/movies,media/tv,downloads,cross-seed/current-cross-seeds}
chown -R ${PUID}:${PGID} "${BASE_PATH}" "${MEDIA_SHARE}"
chmod -R 775 "${BASE_PATH}" "${MEDIA_SHARE}"
```

## 3. Configure ProtonVPN WireGuard
Follow the [ProtonVPN WireGuard Setup Guide](protonvpn-wireguard.md) to configure the VPN on the host.
Ensure `wg0` is up and running before deploying the stack.

## 4. Validate Environment
Run the validation scripts to ensure ports are free and VPN is working:
```bash
# Check for port conflicts
./scripts/check-ports.sh

# Verify VPN routing (after setting up WireGuard)
./scripts/verify-qb-wg.sh
```

## 5. Deploy the Stack
Deploy the stack using Docker Compose:
```bash
docker compose up -d
```

## 6. Verify Deployment
- Check running containers:
  ```bash
  docker compose ps
  ```
- Access services via their web UIs (ports defined in `.env`).
- Verify qBittorrent is routing through the VPN:
  ```bash
  ./scripts/verify-qb-wg.sh
  ```

## 7. Maintenance
- **Update**: `docker compose pull && docker compose up -d`
- **Stop**: `docker compose down`
- **Logs**: `docker compose logs -f [service_name]`
