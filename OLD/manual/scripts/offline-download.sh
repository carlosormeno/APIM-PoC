#!/usr/bin/env bash
set -euo pipefail

DEST_BASE="/Datos/offline"
DEST_IMAGES="$DEST_BASE/images"
LIST_FILE="$DEST_BASE/images-wso2-base.txt"
TAR_FILE="$DEST_BASE/apim-wso2-base-images.tar"

mkdir -p "$DEST_IMAGES"

# Collect images from manifests (base + observability + ingress + wso2)
python - <<'PY'
from pathlib import Path
import re

roots = [
    Path('manual/manifests/ingress'),
    Path('manual/manifests/base/cert-manager'),
    Path('manual/manifests/observability'),
    Path('manual/manifests/wso2'),
]
images = set()
pattern = re.compile(r'\bimage:\s*([\w\./:-]+)')

for root in roots:
    if not root.exists():
        continue
    for p in root.rglob('*.yaml'):
        try:
            text = p.read_text()
        except Exception:
            continue
        for m in pattern.finditer(text):
            images.add(m.group(1).strip('"'))

# Add known init-container images if missing
images.add('alpine:3.20')

for img in sorted(images):
    print(img)
PY > "$LIST_FILE"

echo "Images list -> $LIST_FILE"

# Pull images
while read -r img; do
  echo "Pulling $img"
  podman pull "$img"
done < "$LIST_FILE"

# Save to tar
echo "Saving all images to $TAR_FILE"
podman save -o "$TAR_FILE" $(cat "$LIST_FILE")

echo "Done. Copy $TAR_FILE and $LIST_FILE to the offline PC."
