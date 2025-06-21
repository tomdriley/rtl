FROM mcr.microsoft.com/devcontainers/base:ubuntu

# Install system dependencies
RUN apt-get update && apt-get install -y \
    # X11 applications for testing and desktop use
    x11-apps \
    xterm \
    gedit \
    # Development tools that might be useful for RTL development
    build-essential \
    git \
    curl \
    wget \
    # Clean up to reduce image size
    && rm -rf /var/lib/apt/lists/*

# Set up any additional environment variables if needed
# ENV DISPLAY=:1

# The base image already includes the vscode user and basic setup
