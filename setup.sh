#!/usr/bin/env bash
set -e

# -----------------------------------------------------------------------------
# Project setup script for Docker + Verilator on WSL2
# Ensures Docker is installed, running, pulls Verilator image, and tests it.
# -----------------------------------------------------------------------------

# 1) Check that Docker CLI is available
if ! command -v docker &> /dev/null; then
  echo "Error: Docker not found. Please install Docker Desktop with WSL2 integration." >&2
  exit 1
fi

# 2) Check that Docker daemon is running
if ! docker info &> /dev/null; then
  echo "Error: Docker daemon not running. Please start Docker Desktop." >&2
  exit 1
fi

# 3) Pull the latest Verilator Docker image
IMAGE="verilator/verilator:latest"
echo "Pulling Docker image $IMAGE..."
docker pull "$IMAGE"

# 4) Verify Verilator is accessible
echo "Testing Verilator version..."
docker run --rm --entrypoint verilator "$IMAGE" --version

# 5) Build the GTK wave docker image
echo "Building GTK wave Docker image..."
docker build -t gtk-wave -f Dockerfile.gtk-wave .
if [ $? -ne 0 ]; then
  echo "Error: Failed to build GTK wave Docker image." >&2
  exit 1
fi

# 6) Verify GTK wave is accessible
echo "Testing GTK wave version..."
docker run --rm -it -v /tmp/.X11-unix:/tmp/.X11-unix -v /mnt/wslg:/mnt/wslg -e DISPLAY gtk-wave gtkwave --version
if [ $? -ne 0 ]; then
  echo "Error: Failed to run GTK wave." >&2
  exit 1
fi

echo "Setup complete. You can now run 'make build' and 'make run'."
