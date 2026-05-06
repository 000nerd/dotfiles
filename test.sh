#!/usr/bin/env bash

# Build the test image
echo "Building Docker test image..."
docker build -t dotfiles-test -f Dockerfile.test .

# Run the test container
echo "Running Docker test container..."
echo "To test the installation, run: ./install.sh"
docker run -it --rm dotfiles-test
