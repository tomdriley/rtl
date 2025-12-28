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

# Check and install system dependencies (Ubuntu/Debian + Fedora only)
ensure_system_dependencies() {
    log_info "Checking system dependencies..."

    # Hard fail if not bash with associative array support
    if ! (echo "${BASH_VERSINFO[0]}" | grep -Eq '^[0-9]+$') || [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
        log_error "This script requires bash >= 4 (associative arrays)."
        return 1
    fi

    # Detect supported OS family + package manager
    local pm=""
    if command -v apt-get >/dev/null 2>&1; then
        pm="apt"
    elif command -v dnf >/dev/null 2>&1; then
        pm="dnf"
    else
        log_error "Unsupported system: only Ubuntu/Debian (apt-get) and Fedora (dnf) are supported."
        return 1
    fi

    # Dependencies expressed as COMMAND -> PACKAGE
    # Note: some commands map to packages that provide them.
    declare -A apt_packages=(
        ["git"]="git"
        ["curl"]="curl"
        ["wget"]="wget"
        ["make"]="make"
        ["gcc"]="gcc"
        ["g++"]="g++"
        ["xeyes"]="x11-apps"
        ["xterm"]="xterm"
        ["gedit"]="gedit"
        ["tree"]="tree"
        ["vim"]="vim"
    )

    declare -A dnf_packages=(
        ["git"]="git"
        ["curl"]="curl"
        ["wget"]="wget"
        ["make"]="make"
        ["gcc"]="gcc"
        ["g++"]="gcc-c++"
        ["xeyes"]="xeyes"
        ["xterm"]="xterm"
        ["gedit"]="gedit"
        ["tree"]="tree"
        ["vim"]="vim"
    )

    local -a missing_cmds=()
    local -a to_install=()

    # Pick the right mapping
    local -n pkgmap
    if [ "$pm" = "apt" ]; then
        pkgmap=apt_packages
        log_info "Using apt-get (Ubuntu/Debian)"
    else
        pkgmap=dnf_packages
        log_info "Using dnf (Fedora)"
    fi

    # Check what commands are missing
    for cmd in "${!pkgmap[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_cmds+=("$cmd")
        fi
    done

    if [ ${#missing_cmds[@]} -eq 0 ]; then
        log_info "All system dependencies are already installed"
        return 0
    fi

    log_info "Missing commands: ${missing_cmds[*]}"

    # Build install list (dedupe)
    declare -A seen_pkg=()
    local cmd pkg
    for cmd in "${missing_cmds[@]}"; do
        pkg="${pkgmap[$cmd]}"
        if [ -n "$pkg" ]; then
            # pkg may contain multiple packages (space-separated)
            for p in $pkg; do
                if [ -z "${seen_pkg[$p]+x}" ]; then
                    to_install+=("$p")
                    seen_pkg["$p"]=1
                fi
            done
        fi
    done

    if [ ${#to_install[@]} -eq 0 ]; then
        log_error "Internal error: no packages mapped for missing commands: ${missing_cmds[*]}"
        return 1
    fi

    log_info "Installing packages: ${to_install[*]}"

    if [ "$pm" = "apt" ]; then
        sudo apt-get update
        sudo apt-get install -y "${to_install[@]}"
    else
        # Fedora best practice
        sudo dnf install -y "${to_install[@]}"
    fi

    # Verify installation succeeded
    local -a still_missing=()
    for cmd in "${missing_cmds[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            still_missing+=("$cmd")
        fi
    done

    if [ ${#still_missing[@]} -gt 0 ]; then
        log_error "Failed to install dependencies; still missing commands: ${still_missing[*]}"
        log_error "You may be on a minimal/headless install or the packages are unavailable in your repos."
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
        if ! docker build -t gtk-wave -f tools/Dockerfile.gtk-wave .; then
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
        if ! docker build -t oss-cad -f tools/Dockerfile.oss-cad .; then
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

# Ensure sv2v Docker image is available and working
ensure_sv2v() {
    log_info "Checking sv2v Docker image..."

    # Check if image exists, build if necessary
    if ! docker image inspect sv2v:latest >/dev/null 2>&1; then
        log_info "sv2v image not found, building..."
        if ! docker build -t sv2v -f tools/Dockerfile.sv2v .; then
            log_error "Failed to build sv2v Docker image"
            return 1
        fi
    else
        log_info "sv2v image already available"
    fi

    # Test sv2v with version check using same config as Makefile
    log_info "Testing sv2v..."

    # Test running sv2v from sv2v image
    if docker run --rm --entrypoint sv2v sv2v --version >/dev/null 2>&1; then
        log_info "sv2v is working correctly"
        return 0
    else
        log_error "sv2v test failed"
        return 1
    fi
}

# Ensure OpenSTA Docker image is available and working
ensure_opensta() {
    log_info "Checking OpenSTA Docker image..."

    # Check if image exists, build if necessary
    if ! docker image inspect opensta:latest >/dev/null 2>&1; then
        log_info "OpenSTA image not found, building..."
        if ! docker build -t opensta -f tools/Dockerfile.opensta .; then
            log_error "Failed to build OpenSTA Docker image"
            return 1
        fi
    else
        log_info "OpenSTA image already available"
    fi

    # Test OpenSTA with version check
    log_info "Testing OpenSTA..."
    if docker run --rm --entrypoint sta opensta -version >/dev/null 2>&1; then
        log_info "OpenSTA is working correctly"
        return 0
    else
        log_error "OpenSTA test failed"
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
    local docker_available=false
    
    if ! ensure_system_dependencies; then
        setup_failed=true
    fi
    
    if ensure_docker; then
        docker_available=true
    else
        setup_failed=true
    fi
    
    if [ "$docker_available" = true ]; then
        if ! ensure_verilator; then
            setup_failed=true
        fi
        
        if ! ensure_gtkwave; then
            setup_failed=true
        fi

        if ! ensure_oss_cad; then
            setup_failed=true
        fi

        if ! ensure_sv2v; then
            setup_failed=true
        fi

        if ! ensure_opensta; then
            setup_failed=true
        fi
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
    log_info "  • make sv2v   - Convert SystemVerilog to Verilog using sv2v"
    log_info "  • make synth  - Synthesize designs with Yosys"
    log_info "  • make sta    - Run static timing analysis with OpenSTA"
    log_info ""
    log_info "Example usage:"
    log_info "  cd examples/hello && make build && make run"
    log_info "  cd examples/waves && make waves"
    log_info "  cd examples/formal && make formal"
    log_info "  cd examples/sv2v && make sv2v"
    log_info "  cd examples/synthesis && make synth"
    log_info "  cd examples/synthesis && make pdk-sky130 && make sta STA_SCRIPT=sta.tcl"
}

# Run main function
main "$@"
