# ADS Endpoint Agent

A unified build system for the AfterDark Security endpoint agent suite.

## Overview

ADS Endpoint Agent is a "virtual package" that orchestrates the building and deployment of:

- **afterdark-darkd** - Core security daemon with threat intelligence, patch monitoring, and file integrity
- **darkd-rk-linuxmalware** - Rootkit and malware scanner module
- **darkd-clamav-plugin** - ClamAV antivirus integration plugin

## Quick Start

```bash
# Clone this repository
git clone https://github.com/afterdarksys/ads-endpoint-agent.git
cd ads-endpoint-agent

# Clone all component repositories
./build.sh clone

# Build everything for all architectures
./build.sh build

# Or build for your current platform only
./build.sh -a osxa build   # macOS ARM
./build.sh -a x86 build    # Linux x86_64
```

## Requirements

- Go 1.21+ (1.22+ for clamav-plugin)
- Git
- Make (optional)
- pkg-config (for clamav-plugin)
- libclamav-dev (for clamav-plugin, optional)

### Platform-Specific

**macOS:**
```bash
brew install go pkg-config clamav  # clamav optional
```

**Linux (Debian/Ubuntu):**
```bash
apt install golang-go pkg-config libclamav-dev  # libclamav-dev optional
```

**Linux (RHEL/CentOS):**
```bash
dnf install golang pkg-config clamav-devel  # clamav-devel optional
```

## Usage

```bash
./build.sh [OPTIONS] [COMMAND]
```

### Commands

| Command | Description |
|---------|-------------|
| `clone` | Clone all component repositories (first-time setup) |
| `pull` | Pull latest changes from all repositories |
| `build` | Build all components (default) |
| `clean` | Clean all build artifacts |
| `install` | Install to system (requires sudo) |
| `help` | Show help message |

### Options

| Option | Description |
|--------|-------------|
| `-a, --arch ARCH` | Target architecture (osxi, osxa, x86, linuxa, win64, all) |
| `-c, --component` | Build specific component (darkd, scanner, clamav, all) |
| `-s, --skip-cgo` | Skip CGO-dependent builds (clamav-plugin) |
| `-v, --verbose` | Verbose output |

### Architectures

| Code | Platform | Architecture |
|------|----------|--------------|
| `osxi` | macOS | Intel (x86_64) |
| `osxa` | macOS | Apple Silicon (ARM64) |
| `x86` | Linux | x86_64 |
| `linuxa` | Linux | ARM64 |
| `win64` | Windows | x86_64 |
| `all` | All | All supported platforms |

## Examples

```bash
# First-time setup
./build.sh clone

# Update all repos and rebuild
./build.sh pull && ./build.sh build

# Build only for macOS ARM
./build.sh -a osxa build

# Build only the scanner component
./build.sh -c scanner build

# Build without ClamAV (if libclamav not available)
./build.sh -s build

# Clean everything
./build.sh clean
```

## Output

Binaries are placed in `/Users/ryan/development/ads-endpoint-agent-binaries/`:

```
ads-endpoint-agent-binaries/
├── osxi/                   # macOS Intel
│   ├── afterdark-darkd
│   ├── darkdadm
│   ├── darkapi
│   └── plugins/
│       ├── darkd-scanner
│       └── clamav-scanner
├── osxa/                   # macOS ARM
├── x86/                    # Linux x86_64
├── linuxa/                 # Linux ARM64
├── win64/                  # Windows x86_64
├── configs/                # Configuration files
├── scripts/                # Install scripts
│   ├── install-linux.sh
│   ├── install-macos.sh
│   └── install-windows.ps1
└── README.md
```

## Installation

After building, run the appropriate install script:

```bash
# Linux
sudo ./ads-endpoint-agent-binaries/scripts/install-linux.sh

# macOS
sudo ./ads-endpoint-agent-binaries/scripts/install-macos.sh

# Windows (PowerShell as Administrator)
.\ads-endpoint-agent-binaries\scripts\install-windows.ps1
```

## Component Repositories

| Repository | Description |
|------------|-------------|
| [afterdark-darkd](https://github.com/afterdarksys/afterdark-darkd) | Core security daemon |
| [darkd-rk-linuxmalware](https://github.com/afterdarksys/darkd-rk-linuxmalware) | Rootkit/malware scanner |
| [darkd-clamav-plugin](https://github.com/afterdarksys/darkd-clamav-plugin) | ClamAV integration |

## Architecture

```
ads-endpoint-agent/          # This repository (build orchestration)
├── build.sh                 # Main build script
└── README.md

../afterdark-darkd/          # Core daemon (cloned by build.sh)
../darkd-rk-linuxmalware/    # Scanner module (cloned by build.sh)
../darkd-clamav-plugin/      # ClamAV plugin (cloned by build.sh)
```

## Module Registration

The build system compiles `darkd-rk-linuxmalware` and `darkd-clamav-plugin` as standalone plugin executables that integrate with `afterdark-darkd` via its gRPC plugin framework:

1. **darkd-scanner** registers as a `Service` plugin providing rootkit/malware scanning
2. **clamav-scanner** registers as a `Service` plugin providing ClamAV-based scanning

Plugins are placed in the `plugins/` subdirectory and automatically discovered by `afterdark-darkd` at runtime.

## License

MIT License - See individual component repositories for specific licenses.

## Contributing

1. Fork the component repository you want to modify
2. Make your changes
3. Submit a pull request to the appropriate repository
