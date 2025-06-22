#!/usr/bin/env bash
set -e

# -----------------------------------------------------------------------------
# RTL Development Environment Setup Script
# 
# This script serves two purposes:
# 1. Native/WSL2: Install all required dependencies and set up the environment
# 2. Dev Container: Verify that pre-installed dependencies are working correctly
# 
# The script automatically detects which environment it's running in.
# -----------------------------------------------------------------------------

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Detect if we're running in a dev container
is_dev_container() {
    # Check for common dev container indicators
    [ -n "$REMOTE_CONTAINERS" ] || [ -n "$CODESPACES" ] || [ -f /.dockerenv ] || [ -n "$VSCODE_REMOTE_CONTAINERS_SESSION" ]
}

# Check and install system dependencies as needed
ensure_system_dependencies() {
    log_info "Checking system dependencies..."
    
    # Define dependencies with their package names for different systems
    declare -A apt_packages=(
        ["git"]="git"
        ["curl"]="curl"
        ["wget"]="wget"
        ["make"]="make"
        ["gcc"]="build-essential"
        ["xeyes"]="x11-apps"
        ["xterm"]="xterm"
        ["gedit"]="gedit"
        ["tree"]="tree"
        ["vim"]="vim"
    )
    
    declare -A yum_packages=(
        ["git"]="git"
        ["curl"]="curl"
        ["wget"]="wget"
        ["make"]="make"
        ["gcc"]="gcc gcc-c++"
        ["xeyes"]="xorg-x11-apps"
        ["xterm"]="xterm"
        ["gedit"]="gedit"
        ["tree"]="tree"
        ["vim"]="vim"
    )
    
    local missing_deps=()
    local to_install=()
    
    # Check which dependencies are missing
    for cmd in "${!apt_packages[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [ ${#missing_deps[@]} -eq 0 ]; then
        log_info "All system dependencies are already installed"
        return 0
    fi
    
    log_info "Missing dependencies: ${missing_deps[*]}"
    
    # Determine what packages to install based on package manager
    if command -v apt-get >/dev/null 2>&1; then
        log_info "Using apt package manager"
        for cmd in "${missing_deps[@]}"; do
            if [ -n "${apt_packages[$cmd]}" ]; then
                to_install+=("${apt_packages[$cmd]}")
            fi
        done
        
        if [ ${#to_install[@]} -gt 0 ]; then
            log_info "Installing packages: ${to_install[*]}"
            sudo apt-get update
            sudo apt-get install -y "${to_install[@]}"
        fi
        
    elif command -v yum >/dev/null 2>&1; then
        log_info "Using yum package manager"
        for cmd in "${missing_deps[@]}"; do
            if [ -n "${yum_packages[$cmd]}" ]; then
                # Handle cases where one command maps to multiple packages
                to_install+=($yum_packages[$cmd])
            fi
        done
        
        if [ ${#to_install[@]} -gt 0 ]; then
            log_info "Installing packages: ${to_install[*]}"
            sudo yum install -y "${to_install[@]}"
        fi
        
    else
        log_warn "No supported package manager found (apt-get or yum)"
        log_warn "Please install missing dependencies manually: ${missing_deps[*]}"
        return 1
    fi
    
    # Verify installation succeeded
    local still_missing=()
    for cmd in "${missing_deps[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            still_missing+=("$cmd")
        fi
    done
    
    if [ ${#still_missing[@]} -gt 0 ]; then
        log_error "Failed to install dependencies: ${still_missing[*]}"
        return 1
    fi
    
    log_info "All system dependencies are now available"
    return 0
}

# Check Docker availability
ensure_docker() {
    log_info "Checking Docker availability..."
    
    # Check if Docker CLI is available
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker CLI not found. Please install Docker Desktop."
        return 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker daemon not running. Please start Docker Desktop."
        return 1
    fi
    
    log_info "Docker is available and running"
    return 0
}

# Ensure Verilator Docker image is available and working
ensure_verilator() {
    local image="verilator/verilator:v5.036"
    log_info "Checking Verilator Docker image..."
    
    # Check if image exists locally
    if ! docker image inspect "$image" >/dev/null 2>&1; then
        log_info "Verilator image not found locally, pulling..."
        docker pull "$image"
    else
        log_info "Verilator image already available locally"
    fi
    
    # Test that Verilator works
    log_info "Testing Verilator..."
    if docker run --rm --entrypoint verilator "$image" --version >/dev/null 2>&1; then
        log_info "Verilator is working correctly"
        return 0
    else
        log_error "Verilator test failed"
        return 1
    fi
}

# Ensure GTK Wave Docker image is available and working
ensure_gtkwave() {
    log_info "Checking GTK Wave Docker image..."
    
    # Check if image exists, build if necessary
    if ! docker image inspect gtk-wave:latest >/dev/null 2>&1; then
        log_info "GTK Wave image not found, building..."
        if ! docker build -t gtk-wave -f Dockerfile.gtk-wave .; then
            log_error "Failed to build GTK Wave Docker image"
            return 1
        fi
    else
        log_info "GTK Wave image already available"
    fi
    
    # Test GTK Wave with version check using same config as Makefile
    log_info "Testing GTK Wave..."
    
    local test_cmd
    if [ -S "/tmp/.X11-unix/X${DISPLAY#:}" ]; then
        # WSL2/WSLg environment
        log_info "Using WSL2/WSLg X11 configuration"
        test_cmd="docker run --rm -it \
            -v /tmp/.X11-unix:/tmp/.X11-unix \
            -v /mnt/wslg:/mnt/wslg \
            -e DISPLAY -e WAYLAND_DISPLAY -e XDG_RUNTIME_DIR \
            --user $(id -u):$(id -g) \
            gtk-wave gtkwave --version"
    else
        # Dev container VNC environment
        log_info "Using dev container VNC configuration"
        local xauth_arg=""
        if [ -f "$HOME/.Xauthority" ]; then
            xauth_arg="-v $HOME/.Xauthority:$HOME/.Xauthority:ro"
        fi
        test_cmd="docker run --rm -it \
            --network host \
            -e DISPLAY=$DISPLAY \
            $xauth_arg \
            --user $(id -u):$(id -g) \
            gtk-wave gtkwave --version"
    fi
    
    if eval "$test_cmd" >/dev/null 2>&1; then
        log_info "GTK Wave is working correctly"
        return 0
    else
        log_error "GTK Wave test failed"
        return 1
    fi
}

# Ensure OSS CAD Docker image is available and working
ensure_oss_cad() {
    log_info "Checking OSS CAD Docker image..."
    
    # Check if image exists, build if necessary
    if ! docker image inspect oss-cad:latest >/dev/null 2>&1; then
        log_info "OSS CAD image not found, building..."
        if ! docker build -t oss-cad -f Dockerfile.oss-cad .; then
            log_error "Failed to build OSS CAD Docker image"
            return 1
        fi
    else
        log_info "OSS CAD image already available"
    fi
    
    # Test OSS CAD with version check using same config as Makefile
    log_info "Testing OSS CAD..."
    
    # Test running SBY from OSS CAD image 
    if docker run --rm --entrypoint sby oss-cad --version >/dev/null 2>&1; then
        log_info "OSS CAD is working correctly"
        return 0
    else
        log_error "OSS CAD test failed"
        return 1
    fi
}

# Main setup logic
main() {
    log_info "Starting RTL development environment setup..."
    
    local environment="unknown"
    if is_dev_container; then
        environment="dev container"
    else
        environment="native/WSL2"
    fi
    
    log_info "Detected environment: $environment"
    log_info "Checking and installing dependencies as needed..."
    
    # Check and ensure all dependencies are available
    local setup_failed=false
    
    if ! ensure_system_dependencies; then
        setup_failed=true
    fi
    
    if ! ensure_docker; then
        setup_failed=true
    fi
    
    if ! ensure_verilator; then
        setup_failed=true
    fi
    
    if ! ensure_gtkwave; then
        setup_failed=true
    fi

    if ! ensure_oss_cad; then
        setup_failed=true
    fi
    
    if [ "$setup_failed" = true ]; then
        log_error "Setup failed - some dependencies could not be installed or verified"
        exit 1
    fi
    
    log_info "Environment setup complete!"
    log_info ""
    log_info "You can now run:"
    log_info "  • make build  - Build Verilog projects"
    log_info "  • make run    - Run simulations"  
    log_info "  • make waves  - View waveforms with GTK Wave"
    log_info "  • make formal - Run formal verification with OSS CAD SBY"
    log_info ""
    log_info "Example usage:"
    log_info "  cd hello && make build && make run"
    log_info "  cd waves && make waves"
    log_info "  cd formal && make formal"
}

# Run main function
main "$@"
