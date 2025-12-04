# Technical Specifications

## Environment
- Host: Linux (tested)
- Runtime: Docker & Docker Compose
- Optional: Portainer for GUI management

## Repository layout (important files)
- Compose variants:
  - `basic-compose.yaml` (basic)
  - `advanced-compose.yml` (advanced)
- Rules & prompts:
  - `.cursor/rules/` — source rule files (plan, implement, debug, memory, directory-structure, etc.)
  - `.clinerules/` — CLINE symlinked rules & mode folders (ACT, PLAN)
- Docs & tasks:
  - `docs/` (architecture, technical, product_requirement_docs.md)
  - `tasks/` (tasks_plan.md, active_context.md, rfc/)

## How to run
1. Choose compose file and rename to `docker-compose.yml`.
2. Fill required environment variables (VPN credentials, paths).
3. Start stack:
   ```
   docker compose up -d
   ```
4. Optional: configure reverse proxy for service subdomains.

## Build / Dev notes
- Keep a single consistent host path for media (e.g., `/share`) to enable hardlinking across containers.
- Use separate branches for rule/template updates; `.cursor/rules` is the canonical source for custom prompts.
- When modifying rule files, preserve symlink targets so `.clinerules/` continues to reference `.cursor/rules/`.

## Automation & AI integration
- This repo now includes the CLINE rules template under `.clinerules/` and `.cursor/rules/`.
- To populate the persistent memory files, run the Cline initialization prompt after enabling runes in VSCode.

## Docker Swarm (Swarm-specific notes)
- The repository includes a Swarm-ready stack file `docker-stack.yml` and deployment helpers under `scripts/`.
- Before deploying to Swarm:
  - Copy `.env.example` to `.env` and edit PUID, PGID, BASE_PATH, MEDIA_SHARE and port overrides.
  - Create required Docker secrets as documented in `SECRETS_README.md`.
  - Initialize Swarm on the manager node (`docker swarm init`) and run deployment from a manager.
- Key differences versus docker-compose:
  - Swarm does not support `network_mode: host` in stack deploys; services requiring host networking (notably Plex for SSDP/discovery or direct hw passthrough) should be run outside Swarm as a standalone container.
  - Use Docker secrets for credentials; services can read secrets from `/run/secrets/<name>` inside the container.
  - Use overlay networks (`media-overlay`, `vpn-overlay`) for inter-service communication across nodes. Reverse proxy consumers should connect to the `proxy` overlay if present.
  - Published ports are controlled in `docker-stack.yml` and can be overridden in `.env`. Validate host ports with `./scripts/validate-ports.sh` before deploying.
- VPN routing for torrent clients:
  - The stack includes `gluetun` (ProtonVPN). In Swarm, service-level network_mode linking is not available; route qbittorrent through gluetun by configuring qbittorrent to use gluetun's exposed proxy (SOCKS/HTTP), or run qbittorrent outside Swarm with `network_mode: service:gluetun` if strict isolation is required.
  - See `docs/deployment.md` for verification steps and recommended options.
- Hardware acceleration:
  - Mount `/dev/dri` into services requiring QuickSync (Plex, tdarr). Verify host drivers and permissions; if host-level device access is required, prefer running that service outside Swarm.
- Files & scripts:
  - `docker-stack.yml` — Swarm stack to deploy with `docker stack deploy`.
  - `.env.example` — variables template.
  - `SECRETS_README.md` — secret creation commands.
  - `scripts/validate-ports.sh` — checks host port conflicts.
  - `scripts/deploy-stack.sh` — helper to create secrets from env and deploy the stack (interactive).
- Reference:
  - See `implementation_plan.md` for the authoritative plan and the port mapping recommendations.
