#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: ./scripts/deploy.sh <ssh-target> [image-name] [container-name] [remote-port]

Example:
  ./scripts/deploy.sh user@target.example.com arachis arachis 8000

Arguments:
  ssh-target     SSH destination for the target device, e.g. user@host
  image-name     Docker image name to build and deploy (default: arachis)
  container-name Docker container name on target (default: arachis)
  remote-port    Port on target to expose the site (default: 8000)

This script builds the static site Docker image locally, transfers it over SSH,
loads it into Docker on the target device, and runs it there.
USAGE
}

if [ "$#" -lt 1 ]; then
  usage
  exit 1
fi

SSH_TARGET="$1"
IMAGE_NAME="${2:-arachis}"
CONTAINER_NAME="${3:-arachis}"
REMOTE_PORT="${4:-8000}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

command -v docker >/dev/null 2>&1 || { echo "docker is required locally." >&2; exit 1; }
command -v ssh >/dev/null 2>&1 || { echo "ssh is required." >&2; exit 1; }

echo "Building Docker image '$IMAGE_NAME'..."
docker build --platform linux/arm64 -t "$IMAGE_NAME" .

echo "Deploying image to '$SSH_TARGET'..."

# Save image to temp file
TEMP_FILE="/tmp/${IMAGE_NAME}.tar"
docker save "$IMAGE_NAME" > "$TEMP_FILE"

# Transfer and load on remote
scp "$TEMP_FILE" "$SSH_TARGET:$TEMP_FILE"
ssh "$SSH_TARGET" bash -se <<EOF
set -e
command -v docker >/dev/null 2>&1 || { echo "docker is required on remote host." >&2; exit 1; }
echo "Loading image on remote host..."
docker load < "$TEMP_FILE"
rm "$TEMP_FILE"
echo "Stopping and removing existing container if present..."
docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
docker rm "$CONTAINER_NAME" >/dev/null 2>&1 || true
echo "Starting container '$CONTAINER_NAME' on port $REMOTE_PORT..."
docker run -d --name "$CONTAINER_NAME" -p "$REMOTE_PORT":8000 --restart unless-stopped "$IMAGE_NAME"
echo "Deployment complete."
EOF

# Clean up local temp file
rm "$TEMP_FILE"

echo "Remote deployment finished. Open http://$SSH_TARGET:$REMOTE_PORT if the host is reachable by that address."
