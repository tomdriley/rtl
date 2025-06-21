#!/usr/bin/env bash
set -e

# -----------------------------------------------------------------------------
# Project setup script for Docker + Verilator
# Ensures Docker is installed, running, pulls Verilator image, and tests it.
# Note: System dependencies are now installed via the dev container Dockerfile
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
IMAGE="verilator/verilator:v5.036"
echo "Pulling Docker image $IMAGE..."
docker pull "$IMAGE"

# 4) Verify Verilator is accessible
echo "Testing Verilator version..."
docker run --rm --entrypoint verilator "$IMAGE" --version

# 5) Build the GTK wave docker image if it doesn't exist
echo "Checking for existing GTK wave Docker image..."

if ! docker image inspect gtk-wave:latest > /dev/null 2>&1; then
  echo "Building GTK wave Docker image..."
  docker build -t gtk-wave -f Dockerfile.gtk-wave .
  if [ $? -ne 0 ]; then
    echo "Error: Failed to build GTK wave Docker image." >&2
    exit 1
  fi
else
  echo "GTK wave Docker image already exists. Skipping build."
fi


# 6) Verify GTK wave is accessible with version check
echo "Testing GTK wave version..."

# Use the exact same Docker configuration as the Makefile
if [ -S "/tmp/.X11-unix/X${DISPLAY#:}" ]; then
  # WSL2/WSLg environment - use same config as Makefile
  echo "Detected WSL2/WSLg environment"
  docker run --rm -it \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -v /mnt/wslg:/mnt/wslg \
    -e DISPLAY -e WAYLAND_DISPLAY -e XDG_RUNTIME_DIR \
    --user $(id -u):$(id -g) \
    gtk-wave gtkwave --version
else
  # Dev container VNC environment - use exact same config as Makefile
  echo "Detected dev container VNC environment"
  docker run --rm -it \
    --network host \
    -e DISPLAY=$DISPLAY \
    $(if [ -f "$HOME/.Xauthority" ]; then echo "-v $HOME/.Xauthority:$HOME/.Xauthority:ro"; fi) \
    --user $(id -u):$(id -g) \
    gtk-wave gtkwave --version
fi

if [ $? -ne 0 ]; then
  echo "Error: GTK wave version check failed." >&2
  exit 1
fi

echo "Setup complete. You can now run 'make build' and 'make run'."
