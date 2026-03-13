#!/usr/bin/env bash
set -Eeuo pipefail

# Builds V1, V2 and V3 images with consistent local and Docker Hub tags.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

docker build -f Dockerfile.v1 -t mysql-5.5.48:optimized-v1 -t abustosp/mysql:5.5.48-optimized-v1 .
docker build -f Dockerfile.v2 -t mysql-5.5.48:optimized-v2 -t abustosp/mysql:5.5.48-optimized-v2 .
docker build -f Dockerfile.v3 -t mysql-5.5.48:optimized-v3 -t abustosp/mysql:5.5.48-optimized-v3 .

echo "Build completo: V1, V2 y V3"
