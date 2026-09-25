#!/usr/bin/env bash
# P1S Camera Relay, by Inigo Dela Vega
# Clone BambuP1Streamer at the pinned commit and build the container image.
# Needs no printer details.
set -euo pipefail
cd "$(dirname "$0")/.."

UPSTREAM_URL=https://github.com/slynn1324/BambuP1Streamer.git
UPSTREAM_COMMIT=7857e5bdf3ccf07deadf0b6d93baf3d8dfb89a8d
IMAGE=localhost/bambu_p1_streamer

if [ ! -d upstream/.git ]; then
  git clone --quiet "$UPSTREAM_URL" upstream
fi
if ! git -C upstream cat-file -e "$UPSTREAM_COMMIT^{commit}" 2>/dev/null; then
  git -C upstream fetch --quiet origin
fi
git -C upstream checkout --quiet --detach "$UPSTREAM_COMMIT"

podman build -t "$IMAGE:${UPSTREAM_COMMIT:0:7}" -t "$IMAGE:latest" upstream

echo
echo "Built $IMAGE from upstream ${UPSTREAM_COMMIT:0:7}"
echo "Image ID: $(podman image inspect --format '{{.Id}}' "$IMAGE:latest")"
