#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$ROOT_DIR"

# Build the test image
echo "Building Docker test image..."
docker build -t dotfiles-test -f tests/docker/Dockerfile .

# Run the test container
echo "Running Docker test container..."
echo "To test the installation, run: ./install.sh"
docker run -it --rm dotfiles-test
