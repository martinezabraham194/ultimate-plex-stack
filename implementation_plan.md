# Implementation Plan

[Overview]
Goal: Replace the Docker Swarm deployment with a basic docker-compose setup and run ProtonVPN WireGuard (wg0) on the host so qBittorrent traffic egresses via ProtonVPN.

Scope & context:
This plan converts the current "ultimate-plex" Swarm-based stack into a simpler docker-compose deployment using the existing basic-compose.yaml as a starting point. ProtonVPN will be configured on the host using WireGuard (wg0). qBittorrent will be run in host network mode so it can bind to the host's VPN interface (wg0) and ensure torrent traffic passes via ProtonVPN. The plan includes safe cleanup steps to remove Swarm artifacts (stacks, services, secrets, networks) before deploying the compose stack, instructions to set up WireGuard using ProtonVPN credentials, port-forward guidance, validation steps, and rollback guidance. Tdarr is explicitly included in the final compose set.

This migration is needed because Docker Swarm cannot reliably grant NET_ADMIN / /dev/net/tun capabilities via stack deploy; running the VPN on the host simplifies capabilities and routing and reduces complexity for Swarms that require special privileges.

[Types]
Describe environment variables and configuration types used by the new compose-based deployment in a single sentence.

Environment / config types (detailed):
- PUID (int) — Linux user id owning container volumes; validation: positive integer.
- PGID (int) — Linux group id owning container volumes; validation: positive integer.
- TZ (string) — Timezone identifier, e.g., "America/New_York".
- BASE_PATH (path) — Absolute path where container configs are mounted; validation: must exist and be writable by PUID/PGID.
- MEDIA_SHARE (path) — Absolute path presenting media files; validation: must exist and contain media directories.
- SERVER_IP (ipv4) — Host LAN IP (optional) used for internal helpers; validation: IPv4 format.
- PLEX_CLAIM (string, optional) — Plex claim token (optional).
- PROTON_WG_CONFIG_PATH (path) — Location of WireGuard (wg0) config on host, e.g., /etc/wireguard/wg0.conf; validation: readable by root.
- WG_INTERFACE (string) — WireGuard interface name, default "wg0".
- QB_WEBUI_PORT (int) — Web UI port for qBittorrent (host port when using host network). Validate: 1-65535.
- QB_TORRENT_PORT (int) — Torrent port used by qBittorrent (host port). Validate: 1-65535.
- Service ports (int) — RADARR_PORT, SONARR_PORT, etc., all ints 1-65535.
- BOOL flags (string "true"/"false") where needed for optional behaviors.

[Files]
Single sentence describing file modifications.

New files, modified files, and other changes:
- New files to create
  - docker-compose.yaml (root) — main docker-compose file built from basic-compose.yaml, adjusted:
    - qBittorrent: network_mode: "host" + env variables to set WEBUI_PORT and TORRENT_PORT (these will map to the host and bind to wg0 IP).
    - Other services (plex, radarr, sonarr, prowlarr, overseerr, tdarr): standard bridge-mode compose entries using .env ports (unchanged from basic-compose.yaml) and volumes from ${BASE_PATH}/...
    - Add restart: unless-stopped and healthcheck where applicable.
  - docs/protonvpn-wireguard.md — step-by-step ProtonVPN (WireGuard) host setup, port-forwarding notes, and verification commands.
  - scripts/cleanup-swarm.sh — idempotent script to remove Swarm stack, gluetun-priv service, related secrets, and the stack networks.
  - scripts/check-ports.sh — utility to check host ports and exit non-zero on conflicts (uses ss).
  - scripts/verify-qb-wg.sh — run-time validator to confirm qBittorrent traffic uses wg0 (curl --interface wg0 ipinfo.io/ip and container link checks).
- Existing files to modify
  - .env — update/add keys: PROTON_WG_CONFIG_PATH, WG_INTERFACE (wg0), ensure QB_WEBUI_PORT and QB_TORRENT_PORT match desired host ports (31808, 8694).
  - basic-compose.yaml — left in repo as reference; the new docker-compose.yaml will be the authoritative file. Optionally update basic-compose.yaml with a header stating the canonical file is docker-compose.yaml.
  - scripts/deploy-stack.sh — add alternate path / flag to deploy compose (docker compose up -d) and a safe flow to call scripts/cleanup-swarm.sh first.
- Files to delete or move
  - Do NOT delete docker-stack.yml automatically. Plan will provide a manual deletion step; user must confirm removal of any compose definitions they no longer want tracked.
- Configuration updates
  - Recommend using Compose format version "3.8" and relying on Docker Engine's `docker compose` plugin (or docker-compose v2+). Document this requirement in docs/deployment.md.

[Functions]
Single sentence describing function/script modifications.

New shell scripts (detailed):
- scripts/cleanup-swarm.sh (path: scripts/cleanup-swarm.sh)
  - Purpose: remove the "ultimate-plex" stack, remove gluetun-priv service, remove secrets used solely by the stack (proton_user, proton_pass, plex_claim if re-created), remove unused overlay networks created by the stack.
  - Behavior:
    - Run as root or docker-admin user.
    - Commands (idempotent sequence):
      - docker stack rm ultimate-plex || true
      - docker service rm gluetun-priv || true
      - docker service ls --filter "name=ultimate-plex" --format '{{.Name}}' | xargs -r -n1 docker service rm || true
      - docker secret rm proton_user proton_pass plex_claim gluetun_openvpn_user gluetun_openvpn_password 2>/dev/null || true
      - docker network ls --filter label=com.docker.stack.namespace=ultimate-plex --format '{{.Name}}' | xargs -r -n1 docker network rm || true
      - Wait loop until docker service ls shows no ultimate-plex service.
    - Outputs a short report of removed items and leftover items requiring manual cleanup.
- scripts/check-ports.sh
  - Purpose: verify required host ports are free after cleanup and before starting docker compose.
  - Behavior:
    - Use ss -tlnp to check a list of required ports from .env and exit non-zero if any are in use.
- scripts/verify-qb-wg.sh
  - Purpose: validate that traffic leaving the host via qBittorrent goes out via wg0 and that the torrent port is reachable (if ProtonVPN provides port forwarding).
  - Behavior:
    - Run curl --interface wg0 https://ipinfo.io/ip and compare to https://ipinfo.io/ip on default interface to ensure VPN is active.
    - Use nc -zv -w 5 <host-public-ip> $QB_TORRENT_PORT (external test) or instruct user to use an external port check service.

Modified functions:
- scripts/deploy-stack.sh
  - Add a new optional flag `--basic` to deploy docker-compose.yaml (docker compose up -d) after running `scripts/cleanup-swarm.sh` and `scripts/check-ports.sh`.
  - Ensure environment is loaded from .env with `set -a && source .env && set +a` where appropriate.

[Classes]
Single sentence describing class modifications.

- No object-oriented classes in this plan; components are shell scripts and compose services. (If future refactor introduces a helper Python utility, add class definitions to that module.)

[Dependencies]
Single sentence describing dependency modifications.

Host / runtime dependencies required (detailed):
- Docker Engine (>= 20.10) and `docker compose` plugin (or docker-compose v2+). Required for running docker-compose.yaml.
- WireGuard utilities on host:
  - wireguard-tools (wg, wg-quick) — used to bring up wg0 from ProtonVPN configuration.
  - systemd (wg-quick@wg0.service) recommended for automatic startup.
- curl, jq, ss (iproute2) — used by validation scripts.
- Optional: protonvpn-cli (if user prefers) — instructions will include both manual WireGuard and official client options.
- If using port forwarding from ProtonVPN, ensure account supports forwarded ports (ProtonVPN Plus/ProtonVPN-specific features); document provider constraints.

[Testing]
Single sentence describing testing approach.

Testing and verification strategy (detailed):
- Unit / smoke scripts:
  - scripts/check-ports.sh — ensure required ports are free.
  - scripts/verify-qb-wg.sh — verify wg0 is up and public IP via wg0 differs from host default and check qBittorrent binds to wg0 IP.
- Manual checks:
  - After cleanup and before deploy, run `ss -tlnp` to confirm ports freed.
  - After starting wg0: `wg show` and `ip addr show wg0` must show WireGuard interface and an assigned IP.
  - Verify public IP: `curl --interface wg0 https://ipinfo.io/ip` shows ProtonVPN IP.
  - Start docker compose: `docker compose up -d` and check `docker ps` and individual container logs.
  - Confirm qBittorrent WebUI accessible via host:31808 (or configured port).
  - Confirm torrent-port accessibility via external port test (if ProtonVPN provides port forwarding): use external host/netcat or online port check.
- Fallback testing:
  - If qBittorrent cannot use forwarded port, ensure DHT/peer discovery still works (rely on magnet links and peers via ProtonVPN network).

[Implementation Order]
Single sentence describing the implementation sequence.

Ordered steps (minimize conflicts and ensure safe rollback):
1. Backup current state (local snapshot)
   - Export list of services and secrets:
     - docker service ls --format '{{.ID}} {{.Name}} {{.Image}}' > /tmp/ultimate-plex-services.txt
     - docker secret ls > /tmp/ultimate-plex-secrets.txt
     - docker stack ps ultimate-plex --no-trunc > /tmp/ultimate-plex-stack-ps.txt
   - Copy current compose/stack files to /tmp/backup-ultimate-plex/.
2. Create scripts and docs
   - Add scripts/cleanup-swarm.sh, scripts/check-ports.sh, scripts/verify-qb-wg.sh
   - Add docs/protonvpn-wireguard.md with step-by-step WireGuard setup for ProtonVPN
   - Add docker-compose.yaml (root) adapted from basic-compose.yaml including Tdarr
   - Update .env with PROTON_WG_CONFIG_PATH and WG_INTERFACE
3. Run cleanup-swarm.sh (idempotent)
   - This removes the Swarm stack "ultimate-plex", gluetun-priv, and the named secrets. Confirm removal by running docker stack ls and docker service ls.
4. Re-check ports
   - Run scripts/check-ports.sh to ensure required host ports are free.
   - If ports remain in use, inspect and stop the conflicting services manually (or let the plan report them).
5. Configure ProtonVPN WireGuard on host
   - Place ProtonVPN WireGuard config at PROTON_WG_CONFIG_PATH (e.g., /etc/wireguard/wg0.conf)
   - Bring up interface:
     - sudo wg-quick up wg0
     - sudo systemctl enable wg-quick@wg0
   - Verify with `wg show` and `ip addr show wg0`
6. Verify VPN egress
   - Run `curl --interface wg0 https://ipinfo.io/ip` and ensure it returns a ProtonVPN IP
7. Start docker-compose
   - docker compose up -d (from repo root pointing to docker-compose.yaml)
   - For qBittorrent, use `network_mode: host` in compose so the container uses the host networking stack, and set qBittorrent to bind its WebUI and torrent port to the WG interface IP within the app (or to 0.0.0.0 if you want it available on all interfaces, but prefer explicitly binding to the wg0 IP in qBittorrent settings).
8. Validate qBittorrent routing
   - Use scripts/verify-qb-wg.sh to confirm traffic egress via wg0.
   - If ProtonVPN supports port forwarding and it's configured, verify torrent port is reachable from the Internet (external test).
9. Finalize and document
   - Update docs/deployment.md with the new compose flow.
   - Mark the Swarm artifacts removed (optionally archive docker-stack.yml and advanced-compose.yml into an archived/old directory).
10. Rollback plan
    - If failure: re-add backup services using docker compose or restore secrets from /tmp/backup-ultimate-plex files and recreate the stack. Document step-by-step.

Notes & Considerations:
- Binding container traffic to a host interface is easiest by using `network_mode: host`. Docker bridge networks do NAT and may not route through wg0 without advanced policy routing. Host networking is the recommended approach when the VPN runs on the host and you want a container's traffic to use the host VPN interface.
- ProtonVPN port forwarding: ProtonVPN's WireGuard support and forwarding rules differ by plan and provider. If an externally reachable torrent port is required, verify that ProtonVPN supports port forwarding for your account and document how to obtain the forwarded port in docs/protonvpn-wireguard.md. Without forwarded port, peer connectivity will be reduced; torrenting remains possible (less optimal) using DHT and peers.
- Security: Running qBittorrent in host network mode reduces isolation. Keep configuration minimal, restrict WebUI with credentials, and consider binding WebUI to localhost + an SSH tunnel if you want stronger protection.

Example commands (quick reference):
- Cleanup Swarm artifacts (manual run)
  - docker stack rm ultimate-plex
  - docker service rm gluetun-priv || true
  - docker secret rm proton_user proton_pass plex_claim 2>/dev/null || true
  - docker network ls --filter label=com.docker.stack.namespace=ultimate-plex --format '{{.Name}}' | xargs -r -n1 docker network rm
- Bring up wg0
  - sudo cp /path/to/proton/wg0.conf /etc/wireguard/wg0.conf
  - sudo chmod 600 /etc/wireguard/wg0.conf
  - sudo wg-quick up wg0
  - sudo systemctl enable wg-quick@wg0
- Verify egress
  - curl --interface wg0 https://ipinfo.io/ip
- Deploy compose
  - docker compose up -d

End of plan.
