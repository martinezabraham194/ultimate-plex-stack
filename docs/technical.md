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
