FROM mcr.microsoft.com/devcontainers/base:ubuntu

# Install system dependencies for RTL development
RUN apt-get update && apt-get install -y \
    # X11 applications for testing and desktop use
    x11-apps \
    xterm \
    gedit \
    # Development tools for RTL development
    build-essential \
    git \
    curl \
    wget \
    make \
    # Additional tools that might be useful
    tree \
    vim \
    # Clean up to reduce image size
    && rm -rf /var/lib/apt/lists/*

# Pre-pull Docker images to speed up setup
# Note: This is commented out to avoid bloating the dev container image
# Uncomment if you want to pre-cache these images
# RUN docker pull verilator/verilator:v5.036 || true

# Set up any additional environment variables if needed
# ENV DISPLAY=:1

# The base image already includes the vscode user and basic setup
