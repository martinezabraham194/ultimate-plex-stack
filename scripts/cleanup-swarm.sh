#!/usr/bin/env bash
# cleanup-swarm.sh
# Idempotent cleanup of Docker Swarm artifacts for "ultimate-plex" stack.
# Removes stack, named services, secrets, configs, and networks labeled by stack.
# Run on a manager node with Docker CLI access.
#
# Usage: sudo ./scripts/cleanup-swarm.sh

set -u

DOCKER_CMD="${DOCKER_CMD:-docker}"
STACK_NAME="${STACK_NAME:-ultimate-plex}"
SERVICE_NAMES=("gluetun-priv")
SECRET_NAMES=("proton_user" "proton_pass" "plex_claim" "gluetun_openvpn_user" "gluetun_openvpn_password")
CONFIG_NAMES=()
# networks labeled by stack namespace will be removed

info() { printf "\e[34m[INFO]\e[0m %s\n" "$*"; }
warn() { printf "\e[33m[WARN]\e[0m %s\n" "$*"; }
err()  { printf "\e[31m[ERROR]\e[0m %s\n" "$*"; }

# check docker connectivity
if ! $DOCKER_CMD info >/dev/null 2>&1; then
  err "Docker not available or you don't have permission to use Docker. Run on a manager node with appropriate privileges."
  exit 1
fi

# Remove stack if present
if $DOCKER_CMD stack ls --format '{{.Name}}' | grep -xq "$STACK_NAME"; then
  info "Removing stack: $STACK_NAME"
  $DOCKER_CMD stack rm "$STACK_NAME" || warn "docker stack rm returned non-zero"
  # wait briefly for services to stop
  info "Waiting for stack services to terminate..."
  sleep 5
else
  info "Stack '$STACK_NAME' not present"
fi

# Remove named services if present
for svc in "${SERVICE_NAMES[@]}"; do
  if $DOCKER_CMD service ls --format '{{.Name}}' | grep -xq "$svc"; then
    info "Removing service: $svc"
    $DOCKER_CMD service rm "$svc" || warn "Failed to remove service $svc"
  else
    info "Service '$svc' not present"
  fi
done

# Remove secrets if present
for s in "${SECRET_NAMES[@]}"; do
  if $DOCKER_CMD secret ls --format '{{.Name}}' | grep -xq "$s"; then
    info "Removing secret: $s"
    $DOCKER_CMD secret rm "$s" || warn "Failed to remove secret $s"
  else
    info "Secret '$s' not present"
  fi
done

# Remove configs if any specified
for c in "${CONFIG_NAMES[@]}"; do
  if $DOCKER_CMD config ls --format '{{.Name}}' | grep -xq "$c"; then
    info "Removing config: $c"
    $DOCKER_CMD config rm "$c" || warn "Failed to remove config $c"
  else
    info "Config '$c' not present"
  fi
done

# Remove networks scoped to stack (label com.docker.stack.namespace)
NETS=$($DOCKER_CMD network ls --filter "label=com.docker.stack.namespace=$STACK_NAME" -q)
if [ -n "$NETS" ]; then
  info "Removing networks labeled for stack '$STACK_NAME'"
  echo "$NETS" | xargs -r $DOCKER_CMD network rm || warn "Failed to remove one or more networks"
else
  info "No networks found for stack '$STACK_NAME'"
fi

# Final checks: list remaining related artifacts (non-fatal)
info "Remaining stacks:"
$DOCKER_CMD stack ls || warn "Unable to list stacks"

info "Remaining services matching pattern:"
$DOCKER_CMD service ls --format '{{.Name}}' | grep -E "^(${STACK_NAME}|gluetun|gluetun-priv)" || true

info "Remaining secrets:"
$DOCKER_CMD secret ls --format '{{.Name}}' | grep -E "$(IFS='|'; echo "${SECRET_NAMES[*]}")" || true

info "Cleanup complete. If you want this script to be executable, run: chmod +x scripts/cleanup-swarm.sh"
