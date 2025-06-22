# RTL Experiments

This repository provides a complete RTL (Register Transfer Level) development environment using Verilator for simulation and GTK Wave for waveform viewing. It supports both dev container and native development workflows.

## 🚀 Quick Start

### Option 1: Dev Container

Open this repository in VS Code with the Dev Containers extension:

1. **Automatic Setup**: All dependencies are pre-installed
2. **VNC Desktop**: Available at http://localhost:6080
3. **Ready to Use**: No manual configuration needed

```bash
# Setup runs automatically, but you can run manually if needed:
make setup

# Try the examples:
cd hello && make build && make run
cd waves && make build && make run && make waves
```

### Option 2: Native/WSL2 Environment

Clone and set up on Ubuntu/WSL2:

```bash
# First time setup (installs all dependencies):
./setup.sh

# Then use normally:
cd hello && make build && make run
cd waves && make build && make run && make waves
```

## 📁 Examples

### Hello World Simulation
```bash
cd hello
make build # Generates Verilator simulation files
make run   # Runs the simulation
```

### Waveform Visualization
```bash
cd waves
make build # Generates simulation files
make run   # Runs simulation and creates VCD file
make waves # Opens waveforms in GTK Wave viewer
```

## 🛠️ Development Environment Features

### Supported Environments

| Environment | Setup | Dependencies | X11/GUI |
|-------------|--------|--------------|---------|
| **Dev Container** | Automatic | Pre-installed | VNC Desktop |
| **WSL2** | `./setup.sh` | Auto-installed | WSLg |
| **Ubuntu/Linux** | `./setup.sh` | Auto-installed | Native X11 |

### What Gets Set Up

The setup process handles:

- ✅ **System Dependencies**: Development tools and X11 applications
- ✅ **Docker Setup**: Verilator and GTK Wave containerized tools
- ✅ **GUI Integration**: Waveform viewer with proper display configuration

The setup script automatically detects your environment and installs only what's missing.

## 🔧 Available Commands

| Command | Description |
|---------|-------------|
| `make setup` | Run setup script to install/verify dependencies |
| `make build` | Build Verilog simulation using Verilator |
| `make run` | Execute the simulation |
| `make waves` | Open waveforms in GTK Wave viewer |
| `make clean` | Clean build artifacts |
| `make rebuild` | Clean and rebuild |

## 📋 Requirements

- **Docker**: For running simulation and waveform viewing tools
- **X11/GUI Support**: For waveform visualization
- **Make**: For build automation
- **Git**: For version control

## 🐛 Troubleshooting

### Common Issues
- **GTK Wave Won't Open**: Check GUI setup (VNC desktop for dev containers)
- **Docker Issues**: Ensure Docker Desktop is running
- **Build Failures**: Try `make clean` then `make build`

Run `./setup.sh` to verify all dependencies are properly installed.
