#!/usr/bin/env bash
set -euo pipefail

# Try to pull a candidate Readarr image and tag it to ghcr.io/linuxserver/readarr:latest
# Usage:
#   bash scripts/preload-readarr-image.sh
# Run this on the Swarm manager (and repeat on each worker) to preload a working image
# so the stack can reference ghcr.io/linuxserver/readarr:latest.
#
# Candidates will be attempted in order until one succeeds.
#
# After a successful pull the script tags the image:
#   docker tag <pulled-image> ghcr.io/linuxserver/readarr:latest
# This lets the existing stack (which references ghcr.io/linuxserver/readarr:latest)
# find the image locally without forcing a remote pull on each node.

CANDIDATES=(
  "linuxserver/readarr:latest"
  "linuxserver/readarr:develop"
  "linuxserver/readarr:nightly"
  "lscr.io/linuxserver/readarr:latest"
  "ghcr.io/linuxserver/readarr:latest"
  "ghcr.io/linuxserver/readarr:nightly"
  "readarr/readarr:develop"
  "readarr/readarr:nightly"
)

TARGET_TAG="ghcr.io/linuxserver/readarr:latest"

echo "Attempting to pull candidate Readarr images..."
for img in "${CANDIDATES[@]}"; do
  echo
  echo "Trying: $img"
  if docker pull "$img"; then
    echo "Pulled: $img"
    echo "Tagging as $TARGET_TAG"
    docker tag "$img" "$TARGET_TAG"
    echo "Success. $TARGET_TAG is now available locally."
    echo "Repeat this script on each worker node, or use docker save/load to distribute the image."
    exit 0
  else
    echo "Failed to pull: $img"
  fi
done

echo
echo "No candidate image could be pulled successfully."
echo "Outputs above show daemon errors. Common causes:"
echo " - Host network/registry access blocked"
echo " - Image moved/renamed or requires authentication (docker login)"
echo " - No matching platform manifest for this host (arm vs amd64)"
echo
echo "Next steps:"
echo " 1) If auth is required: run 'docker login <registry>' before retrying."
echo " 2) If platform mismatch: try a different tag/architecture-compatible image or run on matching hardware."
echo " 3) To distribute a pulled image to other nodes: on the node that pulled successfully run:"
echo "      docker save ghcr.io/linuxserver/readarr:latest -o readarr.tar"
echo "    then copy readarr.tar to each worker and run:"
echo "      docker load -i readarr.tar"
echo
exit 1
