# ADS Endpoint Agent

A unified security agent suite for endpoint protection and threat detection.

## Features

ADS Endpoint Agent provides comprehensive endpoint security through modular components:

- **Core Security Daemon** - Threat intelligence integration, patch monitoring, and file integrity checking
- **Rootkit & Malware Scanner** - Detection of rootkits, hidden processes, and Linux malware
- **ClamAV Integration** - Optional antivirus scanning via ClamAV engine
- **Cross-Platform Support** - Builds for macOS (Intel/ARM), Linux (x86_64/ARM64), and Windows
- **Plugin Architecture** - Extensible gRPC-based plugin framework for custom modules

## Precompiled Binaries

Download ready-to-use binaries from the releases repository:

**[ads-endpoint-agent-binaries](https://github.com/afterdarksys/ads-endpoint-agent-binaries)**

## Usage

After installation, the agent runs as a system service:

```bash
# Start the daemon
sudo systemctl start darkd        # Linux
sudo launchctl load /Library/LaunchDaemons/com.afterdark.darkd.plist  # macOS

# Administration
darkdadm status                   # Check agent status
darkdadm scan --full              # Run full system scan
darkdadm update                   # Update threat signatures

# API access
darkapi health                    # Check API health
darkapi scan /path/to/check       # Scan specific path
```

## Installation

### From Precompiled Binaries

Download from [ads-endpoint-agent-binaries](https://github.com/afterdarksys/ads-endpoint-agent-binaries) and run the install script:

```bash
# Linux
sudo ./scripts/install-linux.sh

# macOS
sudo ./scripts/install-macos.sh

# Windows (PowerShell as Administrator)
.\scripts\install-windows.ps1
```

### From Source

See [Building](#building) below to compile from source.

## How It Works

ADS Endpoint Agent uses a modular architecture:

```
afterdark-darkd (Core Daemon)
├── Threat Intelligence Module
├── Patch Monitoring
├── File Integrity Monitoring
└── Plugin Host (gRPC)
    ├── darkd-scanner (Rootkit/Malware)
    └── clamav-scanner (Antivirus)
```

Plugins are standalone executables that register with the core daemon via gRPC. They're automatically discovered from the `plugins/` directory at runtime.

### Component Repositories

| Repository | Description |
|------------|-------------|
| [afterdark-darkd](https://github.com/afterdarksys/afterdark-darkd) | Core security daemon |
| [darkd-rk-linuxmalware](https://github.com/afterdarksys/darkd-rk-linuxmalware) | Rootkit/malware scanner |
| [darkd-clamav-plugin](https://github.com/afterdarksys/darkd-clamav-plugin) | ClamAV integration |

---

## Building

This repository is a "virtual package" that orchestrates building all components from source.

### Requirements

- Go 1.21+ (1.22+ for clamav-plugin)
- Git
- Make (optional)
- pkg-config (for clamav-plugin)
- libclamav-dev (for clamav-plugin, optional)

#### Platform-Specific Dependencies

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

### Quick Start

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

### Build Commands

```bash
./build.sh [OPTIONS] [COMMAND]
```

| Command | Description |
|---------|-------------|
| `clone` | Clone all component repositories (first-time setup) |
| `pull` | Pull latest changes from all repositories |
| `build` | Build all components (default) |
| `clean` | Clean all build artifacts |
| `install` | Install to system (requires sudo) |
| `help` | Show help message |

### Build Options

| Option | Description |
|--------|-------------|
| `-a, --arch ARCH` | Target architecture (osxi, osxa, x86, linuxa, win64, all) |
| `-c, --component` | Build specific component (darkd, scanner, clamav, all) |
| `-s, --skip-cgo` | Skip CGO-dependent builds (clamav-plugin) |
| `-v, --verbose` | Verbose output |

### Target Architectures

| Code | Platform | Architecture |
|------|----------|--------------|
| `osxi` | macOS | Intel (x86_64) |
| `osxa` | macOS | Apple Silicon (ARM64) |
| `x86` | Linux | x86_64 |
| `linuxa` | Linux | ARM64 |
| `win64` | Windows | x86_64 |
| `all` | All | All supported platforms |

### Build Examples

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

### Build Output

Binaries are placed in `../ads-endpoint-agent-binaries/`:

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

### Repository Structure

```
ads-endpoint-agent/          # This repository (build orchestration)
├── build.sh                 # Main build script
└── README.md

../afterdark-darkd/          # Core daemon (cloned by build.sh)
../darkd-rk-linuxmalware/    # Scanner module (cloned by build.sh)
../darkd-clamav-plugin/      # ClamAV plugin (cloned by build.sh)
```

---

## License

MIT License - See individual component repositories for specific licenses.

## Contributing

1. Fork the component repository you want to modify
2. Make your changes
3. Submit a pull request to the appropriate repository
