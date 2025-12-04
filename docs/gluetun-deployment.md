# gluetun deployment notes (Swarm / compose)

Summary
- Docker Swarm `stack deploy` does NOT honor `cap_add` or `devices` fields from a Compose file. You cannot grant NET_ADMIN or bind `/dev/net/tun` from within a stack file.
- For gluetun (or any VPN container that needs NET_ADMIN and /dev/net/tun) use either:
  1. A privileged Swarm service created with `docker service create` (run on a manager), or
  2. Run the container outside Swarm with `docker run ... --cap-add NET_ADMIN --device /dev/net/tun ...` (recommended for simplicity and reliability).

Recommended examples

- docker run (recommended)
```bash
docker run -d --name gluetun \
  --cap-add=NET_ADMIN \
  --device /dev/net/tun \
  -v "${BASE_PATH}/gluetun:/gluetun" \
  -e TZ="${TZ}" -e VPNSP=protonvpn -e REGION="${PROTONVPN_REGION}" \
  -p 31888:8888 \
  qmcgaw/gluetun:latest
```

- docker service create (Swarm, must be run on manager)
```bash
docker service create --name gluetun-priv \
  --replicas 1 \
  --cap-add NET_ADMIN \
  --mount type=bind,src="${BASE_PATH}/gluetun",dst=/gluetun \
  --mount type=bind,src=/dev/net/tun,dst=/dev/net/tun \
  --env TZ="${TZ}" --env VPNSP=protonvpn --env REGION="${PROTONVPN_REGION}" \
  --secret proton_user --secret proton_pass \
  --publish published=31888,target=8888,mode=host \
  qmcgaw/gluetun:latest
```

Informational compose snippet (ignored by `stack deploy`)
- Keep this in Compose only for documentation / `docker-compose` users. Swarm will ignore these fields.
```yaml
gluetun:
  image: qmcgaw/gluetun:latest
  cap_add:
    - NET_ADMIN
  devices:
    - /dev/net/tun:/dev/net/tun
  volumes:
    - ${BASE_PATH}/gluetun:/gluetun
  ports:
    - 31888:8888
```

Helper script
- A helper script was added at `scripts/create-gluetun-priv-service.sh` that builds and runs the `docker service create` command on a manager node. Review and run that script on a manager when ready.

Verification
- For the privileged service:
  - docker service ps --no-trunc gluetun-priv
  - docker service logs --tail 200 gluetun-priv
- For a standalone container:
  - docker ps -f name=gluetun
  - docker logs --tail 200 gluetun

Notes
- If you run gluetun outside Swarm, other Swarm services cannot use `network_mode: service:gluetun` — you must configure those services to use gluetun's proxy (HTTP/SOCKS) or run those services outside Swarm as well.
- Keep secrets and credentials secure; Swarm secrets are available to services created via `docker service create`, but not to `docker run` containers unless you mount files or pass env variables.

Compose (docker-compose) usage
- When running with plain docker-compose (non-swarm) you can bind-mount a Proton/other WireGuard config into the gluetun container and tell the image to use the mounted file via `WIREGUARD_CONF_SECRETFILE`.
- Example compose snippet (minimal, relevant fields):
```yaml
gluetun:
  image: qmcgaw/gluetun:latest
  container_name: gluetun
  cap_add:
    - NET_ADMIN
  devices:
    - /dev/net/tun:/dev/net/tun
  environment:
    - TZ=${TZ}
    - VPN_TYPE=wireguard
    - WIREGUARD_CONF_SECRETFILE=/run/secrets/wg0.conf
  volumes:
    - ./config/wireguard/wg0.conf:/run/secrets/wg0.conf:ro
  ports:
    - "${QB_WEBUI_PORT}:31808"
    - "${QB_TORRENT_PORT}:8694"
  restart: unless-stopped
```
- Important:
  - The gluetun image has defaults for many env vars. If you want the container to use a provided WireGuard config file (bind-mounted), avoid setting provider-specific server-selection envs (e.g., REGION, SERVER_REGIONS) that cause the image to try server selection. Supplying just `VPN_TYPE=wireguard` and `WIREGUARD_CONF_SECRETFILE=/run/secrets/wg0.conf` with the bind mount is the simplest approach.
  - The upstream image may have a default `VPN_SERVICE_PROVIDER` set in the image metadata. If that causes provider validation errors, explicitly set `VPN_SERVICE_PROVIDER` in your compose to the correct provider (e.g., `protonvpn`) or leave it unset and prefer mounting a complete wg config.
  - Docker Compose will read .env values; ensure you do not have lingering provider envs in your `.env` that conflict with the desired behavior.

Verification and troubleshooting
- Files to inspect inside the gluetun container:
  - /tmp/gluetun/ip — public IP the container sees (written by the container when PUBLICIP is enabled)
  - /tmp/gluetun/forwarded_port — forwarded port (if provider and plan support port forwarding)
- Useful verification commands (run from host):
  - Tail gluetun logs:
    docker compose -f docker-compose.yaml logs --no-color --tail 200 gluetun
  - Show gluetun public IP file:
    docker exec gluetun sh -c 'cat /tmp/gluetun/ip || true'
  - Show forwarded port (if available):
    docker exec gluetun sh -c 'cat /tmp/gluetun/forwarded_port || true'
  - Use an ephemeral curl container attached to gluetun's network namespace for in-container checks (preferred over editing the official image):
    docker run --rm --network container:gluetun curlimages/curl:8.2.1 -sS https://ipinfo.io/ip
    docker run --rm --network container:gluetun curlimages/curl:8.2.1 -I http://127.0.0.1:31808
  - Re-run repository verification helper:
    bash scripts/verify-qb-wg.sh
  - External torrent-port reachability (use a remote machine or online TCP port test):
    nc -vz <public_ip_or_forwarded_host> <forwarded_port_or_8694>

Common issues and fixes
- Image picks up wrong provider / server-selection errors:
  - Check `.env` and compose for any provider envs (VPNSP, REGION, SERVER_REGIONS, VPN_SERVICE_PROVIDER). Remove or correct conflicting vars before recreating containers.
  - If the image default sets a provider (e.g., PIA) and that conflicts with WireGuard usage, explicitly set `VPN_SERVICE_PROVIDER` in compose to the correct provider or ensure the mounted WireGuard config contains the necessary keys and server info.
- curl not present inside gluetun:
  - Prefer ephemeral curl container with `--network container:gluetun` for in-container network checks rather than modifying the official image.
  - The repository verification script includes a fallback to read `/tmp/gluetun/ip` if curl isn't available.
- Ports not listening on host:
  - When using `network_mode: "service:gluetun"` for qbittorrent, host bindings for the gluetun service (ports: hostPort:containerPort) expose WebUI/torrent ports. Ensure the gluetun container is healthy and WireGuard is up before relying on those host listeners.

Documentation updates
- After any change to compose or WireGuard files, document the following in this file:
  - Exact compose snippet used
  - Location of mounted wg config and any secrets used
  - Commands used for verification
  - Any provider-specific notes (e.g., ProtonVPN forwarded port caveats)

</final_file_content>
