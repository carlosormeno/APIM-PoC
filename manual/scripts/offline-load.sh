#!/usr/bin/env bash
set -euo pipefail

DEST_BASE="/Datos/offline"
TAR_FILE="$DEST_BASE/apim-wso2-base-images.tar"

if [[ ! -f "$TAR_FILE" ]]; then
  echo "Missing $TAR_FILE"
  exit 1
fi

echo "Loading images from $TAR_FILE"
podman load -i "$TAR_FILE"

echo "Done."
