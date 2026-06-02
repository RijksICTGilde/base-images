#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Building base image..."
docker build -t nginx-base-local "${SCRIPT_DIR}"

read -rp "Path to website files [./example]: " SITE_PATH
SITE_PATH="${SITE_PATH:-./example}"

if [ ! -d "$SITE_PATH" ]; then
    echo "Error: '${SITE_PATH}' is not a directory"
    exit 1
fi

if [ ! -f "${SITE_PATH}/index.html" ]; then
    echo "Warning: no index.html found in '${SITE_PATH}'"
    read -rp "Continue anyway? [y/N] " CONFIRM
    [[ "$CONFIRM" =~ ^[Yy]$ ]] || exit 1
fi

read -rp "Image name [my-site]: " IMAGE_NAME
IMAGE_NAME="${IMAGE_NAME:-my-site}"

echo "Building site image..."
docker build -t "${IMAGE_NAME}" -f - "${SITE_PATH}" <<'DOCKERFILE'
FROM nginx-base-local
COPY . /usr/share/nginx/html/
DOCKERFILE

echo ""
echo "Done! Run with:"
echo "  docker run -p 8080:8080 ${IMAGE_NAME}"
