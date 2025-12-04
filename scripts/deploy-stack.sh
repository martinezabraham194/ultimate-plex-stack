#!/usr/bin/env bash
set -euo pipefail

# scripts/deploy-stack.sh
# Helper to validate ports, ensure required Docker secrets exist (or create from env),
# and deploy the Swarm stack.
#
# Usage:
#   ./scripts/deploy-stack.sh        # interactive: may create secrets from env or prompt
#   ./scripts/deploy-stack.sh --dry  # run validation and print the docker stack deploy command without executing
#
# Make executable: chmod +x scripts/deploy-stack.sh

DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --dry|-n) DRY_RUN=1 ;;
    *) ;;
  esac
done

# Load .env if present
if [ -f .env ]; then
  # shellcheck disable=SC1091
  set -o allexport; source .env; set +o allexport
fi

STACK_NAME="${STACK_NAME:-ultimate-plex}"

command -v docker >/dev/null 2>&1 || { echo "docker CLI required but not found"; exit 1; }
command -v ss >/dev/null 2>&1 || echo "warning: ss not found; port validation may fail"

# Ensure Swarm mode active
if ! docker info 2>/dev/null | grep -i 'Swarm: active' >/dev/null 2>&1; then
  echo "ERROR: Docker Swarm is not active on this node. Initialize with: docker swarm init"
  exit 1
fi

# Validate host ports
echo "Running port validation..."
if ! ./scripts/validate-ports.sh; then
  echo "Port validation failed. Fix port conflicts or update .env and retry."
  exit 2
fi

# Required secrets (name -> env var fallback)
declare -A REQUIRED_SECRETS=(
  [proton_user]=PROTONVPN_USER
  [proton_pass]=PROTONVPN_PASS
  [plex_claim]=PLEX_CLAIM
  [sonarr_api_key]=SONARR_KEY
  [radarr_api_key]=RADARR_KEY
  [membarr_token]=MEMBARR_TOKEN
)

# Helper: check if secret exists
secret_exists() {
  local name="$1"
  docker secret ls --format '{{.Name}}' | grep -xF -- "$name" >/dev/null 2>&1
}

# Create secret from env var (if set)
create_secret_from_env() {
  local secret_name="$1"
  local env_var_name="$2"
  local val="${!env_var_name:-}"
  if [ -n "$val" ]; then
    echo -n "$val" | docker secret create "$secret_name" - >/dev/null
    echo "Created secret: $secret_name (from env $env_var_name)"
    return 0
  fi
  return 1
}

# Interactive prompt to create missing secrets
for name in "${!REQUIRED_SECRETS[@]}"; do
  if secret_exists "$name"; then
    echo "Secret present: $name"
    continue
  fi

  envvar="${REQUIRED_SECRETS[$name]}"
  if create_secret_from_env "$name" "$envvar"; then
    continue
  fi

  # If dry-run, report missing and continue
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "DRY: secret missing: $name (would prompt/create interactively)"
    continue
  fi

  # Ask user to create secret interactively
  echo
  printf "Docker secret '%s' is missing. Choose an option:\n" "$name"
  printf "  1) Enter value now (stdin)\n"
  printf "  2) Skip (must exist before deploy)\n"
  printf "  3) Abort\n"
  read -rp "Select [1/2/3]: " choice
  case "$choice" in
    1)
      read -rsp "Enter value for secret $name: " secret_val
      echo
      echo -n "$secret_val" | docker secret create "$name" -
      echo "Created secret: $name"
      ;;
    2)
      echo "Skipping creation of $name. Ensure it exists before deploying the stack."
      ;;
    3)
      echo "Aborting deploy."
      exit 1
      ;;
    *)
      echo "Invalid option. Aborting."
      exit 1
      ;;
  esac
done

# Final deploy command
DEPLOY_CMD=(docker stack deploy --compose-file docker-stack.yml "$STACK_NAME")

echo
echo "Ready to deploy stack: ${STACK_NAME}"
echo "Compose file: docker-stack.yml"
if [ "$DRY_RUN" -eq 1 ]; then
  echo "DRY RUN: would run:"
  echo "${DEPLOY_CMD[*]}"
  exit 0
fi

# Execute deploy
echo "Deploying..."
"${DEPLOY_CMD[@]}"

echo "Deployment command issued. Check services with:"
echo "  docker stack services $STACK_NAME"
echo "  docker service ls | grep $STACK_NAME"
echo
echo "To view logs for a service:"
echo "  docker service logs --tail 200 ${STACK_NAME}_qbittorrent"
echo
echo "If you need to rollback/remove the stack:"
echo "  docker stack rm $STACK_NAME"
