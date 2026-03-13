#!/usr/bin/env bash
set -Eeuo pipefail

# Pushes pre-tagged V1, V2 and V3 images to Docker Hub.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

docker push abustosp/mysql:5.5.48-optimized-v1
docker push abustosp/mysql:5.5.48-optimized-v2
docker push abustosp/mysql:5.5.48-optimized-v3

echo "Push completo: V1, V2 y V3"
