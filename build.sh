#!/bin/bash
#
# ADS Endpoint Agent - Unified Build System
# Builds all components: afterdark-darkd, darkd-rk-linuxmalware, darkd-clamav-plugin
#
set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
BINARIES_DIR="/Users/ryan/development/ads-endpoint-agent-binaries"

# Auto-detect repository locations
# Check for submodules layout first (components/), then sibling directories
detect_repo_layout() {
    if [ -d "${SCRIPT_DIR}/components/afterdark-darkd" ]; then
        # Submodules layout
        DARKD_REPO="${SCRIPT_DIR}/components/afterdark-darkd"
        SCANNER_REPO="${SCRIPT_DIR}/components/darkd-rk-linuxmalware"
        CLAMAV_REPO="${SCRIPT_DIR}/components/darkd-clamav-plugin"
        REPO_LAYOUT="submodules"
    else
        # Sibling directories layout
        DARKD_REPO="${PARENT_DIR}/afterdark-darkd"
        SCANNER_REPO="${PARENT_DIR}/darkd-rk-linuxmalware"
        CLAMAV_REPO="${PARENT_DIR}/darkd-clamav-plugin"
        REPO_LAYOUT="siblings"
    fi
}
detect_repo_layout

# GitHub repository URLs
DARKD_URL="https://github.com/afterdarksys/afterdark-darkd.git"
SCANNER_URL="https://github.com/afterdarksys/darkd-rk-linuxmalware.git"
CLAMAV_URL="https://github.com/afterdarksys/darkd-clamav-plugin.git"

# Supported platforms
PLATFORMS=(
    "darwin/amd64:osxi"
    "darwin/arm64:osxa"
    "linux/amd64:x86"
    "linux/arm64:linuxa"
    "windows/amd64:win64"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# Print banner
print_banner() {
    echo ""
    echo "=============================================="
    echo "   ADS Endpoint Agent - Build System"
    echo "=============================================="
    echo ""
}

# Show usage
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] [COMMAND]

Commands:
    clone       Clone all repositories (first-time setup)
    pull        Pull latest changes from all repositories
    build       Build all components (default)
    build-arch  Build for specific architecture
    clean       Clean all build artifacts
    install     Install to system (requires sudo)
    help        Show this help message

Options:
    -a, --arch ARCH     Target architecture (osxi, osxa, x86, linuxa, win64, all)
    -c, --component     Build specific component (darkd, scanner, clamav, all)
    -s, --skip-cgo      Skip CGO-dependent builds (clamav-plugin)
    -v, --verbose       Verbose output
    -h, --help          Show this help message

Architectures:
    osxi    - macOS Intel (darwin/amd64)
    osxa    - macOS ARM (darwin/arm64)
    x86     - Linux x86_64 (linux/amd64)
    linuxa  - Linux ARM64 (linux/arm64)
    win64   - Windows 64-bit (windows/amd64)
    all     - Build for all architectures

Examples:
    $(basename "$0") clone                  # First-time setup
    $(basename "$0") pull && $(basename "$0") build    # Update and build
    $(basename "$0") -a osxa build          # Build for macOS ARM only
    $(basename "$0") -c scanner build       # Build scanner only
    $(basename "$0") clean                  # Clean all artifacts

EOF
}

# Clone repositories
clone_repos() {
    log_info "Cloning repositories..."

    if [ ! -d "$DARKD_REPO" ]; then
        log_info "Cloning afterdark-darkd..."
        git clone "$DARKD_URL" "$DARKD_REPO"
    else
        log_warn "afterdark-darkd already exists at $DARKD_REPO"
    fi

    if [ ! -d "$SCANNER_REPO" ]; then
        log_info "Cloning darkd-rk-linuxmalware..."
        git clone "$SCANNER_URL" "$SCANNER_REPO"
    else
        log_warn "darkd-rk-linuxmalware already exists at $SCANNER_REPO"
    fi

    if [ ! -d "$CLAMAV_REPO" ]; then
        log_info "Cloning darkd-clamav-plugin..."
        git clone "$CLAMAV_URL" "$CLAMAV_REPO"
    else
        log_warn "darkd-clamav-plugin already exists at $CLAMAV_REPO"
    fi

    log_success "All repositories cloned successfully"
}

# Pull latest changes
pull_repos() {
    log_info "Pulling latest changes..."

    for repo in "$DARKD_REPO" "$SCANNER_REPO" "$CLAMAV_REPO"; do
        if [ -d "$repo" ]; then
            log_info "Pulling $(basename "$repo")..."
            (cd "$repo" && git pull)
        else
            log_error "Repository not found: $repo"
            log_info "Run '$(basename "$0") clone' first"
            exit 1
        fi
    done

    log_success "All repositories updated"
}

# Create output directory structure
setup_output_dirs() {
    log_info "Setting up output directories..."

    mkdir -p "$BINARIES_DIR"

    for platform in "${PLATFORMS[@]}"; do
        arch_suffix="${platform#*:}"
        mkdir -p "$BINARIES_DIR/$arch_suffix"
        mkdir -p "$BINARIES_DIR/$arch_suffix/plugins"
    done

    mkdir -p "$BINARIES_DIR/configs"
    mkdir -p "$BINARIES_DIR/scripts"

    log_success "Output directories created at $BINARIES_DIR"
}

# Get version info
get_version() {
    local repo="$1"
    local version=""

    if [ -f "$repo/VERSION" ]; then
        version=$(cat "$repo/VERSION")
    else
        version=$(cd "$repo" && git describe --tags --always 2>/dev/null || echo "dev")
    fi

    echo "$version"
}

# Build afterdark-darkd
build_darkd() {
    local goos="$1"
    local goarch="$2"
    local suffix="$3"

    log_info "Building afterdark-darkd for $goos/$goarch..."

    cd "$DARKD_REPO"

    local version=$(get_version "$DARKD_REPO")
    local commit=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    local build_time=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

    local ldflags="-s -w -X main.Version=${version} -X main.Commit=${commit} -X main.BuildTime=${build_time}"

    local ext=""
    [ "$goos" = "windows" ] && ext=".exe"

    # Build main daemon
    GOOS="$goos" GOARCH="$goarch" CGO_ENABLED=0 go build \
        -ldflags "$ldflags" \
        -o "$BINARIES_DIR/$suffix/afterdark-darkd${ext}" \
        ./cmd/afterdark-darkd/

    # Build admin CLI
    GOOS="$goos" GOARCH="$goarch" CGO_ENABLED=0 go build \
        -ldflags "$ldflags" \
        -o "$BINARIES_DIR/$suffix/darkdadm${ext}" \
        ./cmd/afterdark-darkdadm/

    # Build user CLI
    GOOS="$goos" GOARCH="$goarch" CGO_ENABLED=0 go build \
        -ldflags "$ldflags" \
        -o "$BINARIES_DIR/$suffix/darkapi${ext}" \
        ./cmd/darkapi/

    log_success "afterdark-darkd built for $suffix"
}

# Build darkd-rk-linuxmalware (scanner)
build_scanner() {
    local goos="$1"
    local goarch="$2"
    local suffix="$3"

    # Scanner only supports linux and darwin
    if [ "$goos" = "windows" ]; then
        log_warn "Skipping darkd-scanner for Windows (not supported)"
        return 0
    fi

    log_info "Building darkd-scanner for $goos/$goarch..."

    cd "$SCANNER_REPO"

    local version=$(get_version "$SCANNER_REPO")
    local build_time=$(date '+%Y-%m-%d_%H:%M:%S')

    local ldflags="-s -w -X main.version=${version} -X main.buildTime=${build_time}"

    GOOS="$goos" GOARCH="$goarch" CGO_ENABLED=0 go build \
        -ldflags "$ldflags" \
        -o "$BINARIES_DIR/$suffix/plugins/darkd-scanner" \
        ./cmd/darkd-scanner/

    log_success "darkd-scanner built for $suffix"
}

# Build darkd-clamav-plugin
build_clamav() {
    local goos="$1"
    local goarch="$2"
    local suffix="$3"

    # ClamAV plugin requires CGO and only works on the native platform
    if [ "$SKIP_CGO" = "true" ]; then
        log_warn "Skipping clamav-scanner (CGO disabled)"
        return 0
    fi

    # Only build for native platform due to CGO
    local native_os=$(go env GOOS)
    local native_arch=$(go env GOARCH)

    if [ "$goos" != "$native_os" ] || [ "$goarch" != "$native_arch" ]; then
        log_warn "Skipping clamav-scanner for $goos/$goarch (CGO cross-compilation not supported)"
        return 0
    fi

    log_info "Building clamav-scanner for $goos/$goarch (native)..."

    cd "$CLAMAV_REPO"

    # Check for libclamav
    if ! pkg-config --exists libclamav 2>/dev/null; then
        # Try Homebrew on macOS
        if [ "$goos" = "darwin" ]; then
            local brew_prefix=$(brew --prefix 2>/dev/null || echo "/opt/homebrew")
            if [ -d "$brew_prefix/opt/clamav/lib/pkgconfig" ]; then
                export PKG_CONFIG_PATH="$brew_prefix/opt/clamav/lib/pkgconfig:$PKG_CONFIG_PATH"
            fi
        fi

        if ! pkg-config --exists libclamav 2>/dev/null; then
            log_warn "libclamav not found - skipping clamav-scanner"
            log_warn "Install with: brew install clamav (macOS) or apt install libclamav-dev (Linux)"
            return 0
        fi
    fi

    CGO_ENABLED=1 go build \
        -o "$BINARIES_DIR/$suffix/plugins/clamav-scanner" \
        ./cmd/clamav-scanner/

    log_success "clamav-scanner built for $suffix"
}

# Build for a specific architecture
build_for_arch() {
    local platform_spec="$1"
    local goos="${platform_spec%/*}"
    local goarch_suffix="${platform_spec#*/}"
    local goarch="${goarch_suffix%:*}"
    local suffix="${goarch_suffix#*:}"

    log_info "Building for $goos/$goarch ($suffix)..."

    case "$BUILD_COMPONENT" in
        darkd)
            build_darkd "$goos" "$goarch" "$suffix"
            ;;
        scanner)
            build_scanner "$goos" "$goarch" "$suffix"
            ;;
        clamav)
            build_clamav "$goos" "$goarch" "$suffix"
            ;;
        all|*)
            build_darkd "$goos" "$goarch" "$suffix"
            build_scanner "$goos" "$goarch" "$suffix"
            build_clamav "$goos" "$goarch" "$suffix"
            ;;
    esac
}

# Main build function
build_all() {
    log_info "Starting build process..."

    setup_output_dirs

    # Verify repositories exist
    for repo in "$DARKD_REPO" "$SCANNER_REPO" "$CLAMAV_REPO"; do
        if [ ! -d "$repo" ]; then
            log_error "Repository not found: $repo"
            log_info "Run '$(basename "$0") clone' first"
            exit 1
        fi
    done

    # Download dependencies
    log_info "Downloading dependencies..."
    (cd "$DARKD_REPO" && go mod download)
    (cd "$SCANNER_REPO" && go mod download)
    (cd "$CLAMAV_REPO" && go mod download)

    # Build for specified architectures
    if [ "$TARGET_ARCH" = "all" ] || [ -z "$TARGET_ARCH" ]; then
        for platform in "${PLATFORMS[@]}"; do
            build_for_arch "$platform"
        done
    else
        # Find matching platform
        local found=false
        for platform in "${PLATFORMS[@]}"; do
            if [[ "$platform" == *":$TARGET_ARCH" ]]; then
                build_for_arch "$platform"
                found=true
                break
            fi
        done

        if [ "$found" = false ]; then
            log_error "Unknown architecture: $TARGET_ARCH"
            log_info "Valid options: osxi, osxa, x86, linuxa, win64, all"
            exit 1
        fi
    fi

    # Copy configuration files
    copy_configs

    # Generate install scripts
    generate_install_scripts

    # Generate README
    generate_readme

    log_success "Build complete! Binaries available at: $BINARIES_DIR"
}

# Copy configuration files
copy_configs() {
    log_info "Copying configuration files..."

    # Copy darkd configs
    if [ -d "$DARKD_REPO/configs" ]; then
        cp -r "$DARKD_REPO/configs/"* "$BINARIES_DIR/configs/" 2>/dev/null || true
    fi

    # Copy scanner config
    if [ -f "$SCANNER_REPO/configs/darkd-scanner.conf.example" ]; then
        cp "$SCANNER_REPO/configs/darkd-scanner.conf.example" "$BINARIES_DIR/configs/"
    fi

    # Copy service definitions
    if [ -d "$DARKD_REPO/scripts/service" ]; then
        cp -r "$DARKD_REPO/scripts/service" "$BINARIES_DIR/scripts/"
    fi
}

# Generate install scripts
generate_install_scripts() {
    log_info "Generating install scripts..."

    # Linux install script
    cat > "$BINARIES_DIR/scripts/install-linux.sh" << 'INSTALL_LINUX'
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINARIES_DIR="$(dirname "$SCRIPT_DIR")"

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
    x86_64) ARCH_DIR="x86" ;;
    aarch64|arm64) ARCH_DIR="linuxa" ;;
    *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

echo "Installing ADS Endpoint Agent for Linux ($ARCH)..."

# Create directories
sudo mkdir -p /usr/local/bin
sudo mkdir -p /etc/afterdark
sudo mkdir -p /var/lib/afterdark/plugins
sudo mkdir -p /var/log/afterdark

# Install binaries
sudo cp "$BINARIES_DIR/$ARCH_DIR/afterdark-darkd" /usr/local/bin/
sudo cp "$BINARIES_DIR/$ARCH_DIR/darkdadm" /usr/local/bin/
sudo cp "$BINARIES_DIR/$ARCH_DIR/darkapi" /usr/local/bin/

# Install plugins
if [ -d "$BINARIES_DIR/$ARCH_DIR/plugins" ]; then
    sudo cp "$BINARIES_DIR/$ARCH_DIR/plugins/"* /var/lib/afterdark/plugins/ 2>/dev/null || true
fi

# Install configuration
if [ ! -f /etc/afterdark/darkd.yaml ]; then
    sudo cp "$BINARIES_DIR/configs/darkd.yaml.example" /etc/afterdark/darkd.yaml 2>/dev/null || true
fi

# Install systemd service
if [ -d /etc/systemd/system ]; then
    sudo cp "$BINARIES_DIR/scripts/service/systemd/afterdark-darkd.service" /etc/systemd/system/
    sudo systemctl daemon-reload
    echo "Systemd service installed. Enable with: sudo systemctl enable afterdark-darkd"
fi

echo "Installation complete!"
INSTALL_LINUX
    chmod +x "$BINARIES_DIR/scripts/install-linux.sh"

    # macOS install script
    cat > "$BINARIES_DIR/scripts/install-macos.sh" << 'INSTALL_MACOS'
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINARIES_DIR="$(dirname "$SCRIPT_DIR")"

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
    x86_64) ARCH_DIR="osxi" ;;
    arm64) ARCH_DIR="osxa" ;;
    *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

echo "Installing ADS Endpoint Agent for macOS ($ARCH)..."

# Create directories
sudo mkdir -p /usr/local/bin
sudo mkdir -p /etc/afterdark
sudo mkdir -p /var/lib/afterdark/plugins
sudo mkdir -p /var/log/afterdark

# Install binaries
sudo cp "$BINARIES_DIR/$ARCH_DIR/afterdark-darkd" /usr/local/bin/
sudo cp "$BINARIES_DIR/$ARCH_DIR/darkdadm" /usr/local/bin/
sudo cp "$BINARIES_DIR/$ARCH_DIR/darkapi" /usr/local/bin/

# Install plugins
if [ -d "$BINARIES_DIR/$ARCH_DIR/plugins" ]; then
    sudo cp "$BINARIES_DIR/$ARCH_DIR/plugins/"* /var/lib/afterdark/plugins/ 2>/dev/null || true
fi

# Install configuration
if [ ! -f /etc/afterdark/darkd.yaml ]; then
    sudo cp "$BINARIES_DIR/configs/darkd.yaml.example" /etc/afterdark/darkd.yaml 2>/dev/null || true
fi

# Install LaunchDaemon
if [ -d /Library/LaunchDaemons ]; then
    sudo cp "$BINARIES_DIR/scripts/service/launchd/com.afterdarksys.darkd.plist" /Library/LaunchDaemons/
    echo "LaunchDaemon installed. Enable with: sudo launchctl load /Library/LaunchDaemons/com.afterdarksys.darkd.plist"
fi

echo "Installation complete!"
INSTALL_MACOS
    chmod +x "$BINARIES_DIR/scripts/install-macos.sh"

    # Windows install script (PowerShell)
    cat > "$BINARIES_DIR/scripts/install-windows.ps1" << 'INSTALL_WINDOWS'
#Requires -RunAsAdministrator
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BinariesDir = Split-Path -Parent $ScriptDir

Write-Host "Installing ADS Endpoint Agent for Windows..."

# Create directories
$InstallDir = "C:\Program Files\AfterDark"
$DataDir = "C:\ProgramData\AfterDark"
$PluginsDir = "$DataDir\plugins"
$LogDir = "$DataDir\logs"

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
New-Item -ItemType Directory -Force -Path $DataDir | Out-Null
New-Item -ItemType Directory -Force -Path $PluginsDir | Out-Null
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

# Copy binaries
Copy-Item "$BinariesDir\win64\afterdark-darkd.exe" "$InstallDir\" -Force
Copy-Item "$BinariesDir\win64\darkdadm.exe" "$InstallDir\" -Force
Copy-Item "$BinariesDir\win64\darkapi.exe" "$InstallDir\" -Force

# Copy plugins
if (Test-Path "$BinariesDir\win64\plugins") {
    Copy-Item "$BinariesDir\win64\plugins\*" "$PluginsDir\" -Force
}

# Copy configuration
if (-not (Test-Path "$DataDir\darkd.yaml")) {
    Copy-Item "$BinariesDir\configs\darkd.yaml.example" "$DataDir\darkd.yaml" -Force
}

# Add to PATH
$currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
if ($currentPath -notlike "*$InstallDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$currentPath;$InstallDir", "Machine")
}

# Register as Windows Service
& "$InstallDir\afterdark-darkd.exe" install 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Windows Service registered. Start with: Start-Service afterdark-darkd"
}

Write-Host "Installation complete!"
INSTALL_WINDOWS

    log_success "Install scripts generated"
}

# Generate README
generate_readme() {
    log_info "Generating README..."

    local version=$(get_version "$DARKD_REPO")
    local build_date=$(date -u '+%Y-%m-%d %H:%M:%S UTC')

    cat > "$BINARIES_DIR/README.md" << README
# ADS Endpoint Agent - Binaries

**Version:** $version
**Build Date:** $build_date

## Contents

This directory contains pre-built binaries for the ADS Endpoint Agent security suite.

### Directory Structure

\`\`\`
ads-endpoint-agent-binaries/
├── osxi/                   # macOS Intel (x86_64)
│   ├── afterdark-darkd     # Main security daemon
│   ├── darkdadm            # Admin CLI
│   ├── darkapi             # User CLI
│   └── plugins/
│       ├── darkd-scanner   # Rootkit/malware scanner
│       └── clamav-scanner  # ClamAV integration (if built)
├── osxa/                   # macOS ARM (Apple Silicon)
│   └── ...
├── x86/                    # Linux x86_64
│   └── ...
├── linuxa/                 # Linux ARM64
│   └── ...
├── win64/                  # Windows x86_64
│   └── ...
├── configs/                # Configuration files
├── scripts/                # Installation scripts
│   ├── install-linux.sh
│   ├── install-macos.sh
│   └── install-windows.ps1
└── README.md               # This file
\`\`\`

## Quick Install

### Linux
\`\`\`bash
sudo ./scripts/install-linux.sh
\`\`\`

### macOS
\`\`\`bash
sudo ./scripts/install-macos.sh
\`\`\`

### Windows (PowerShell as Administrator)
\`\`\`powershell
.\scripts\install-windows.ps1
\`\`\`

## Components

### afterdark-darkd
The main security daemon providing:
- System baseline monitoring
- File integrity monitoring
- Network connection tracking
- Process monitoring
- Threat intelligence integration
- Patch compliance monitoring

### darkdadm
Administrative CLI for:
- Service management
- Configuration updates
- Policy management
- System reports

### darkapi
User CLI for:
- Status queries
- Manual scans
- Event viewing

### Plugins

#### darkd-scanner
Rootkit and malware scanner module:
- Kernel module analysis
- Hidden process detection
- File signature scanning
- Behavioral analysis

#### clamav-scanner
ClamAV antivirus integration:
- Real-time file scanning
- Signature-based detection
- Quarantine management

## Configuration

Default configuration location:
- Linux/macOS: \`/etc/afterdark/darkd.yaml\`
- Windows: \`C:\ProgramData\AfterDark\darkd.yaml\`

## Service Management

### Linux (systemd)
\`\`\`bash
sudo systemctl start afterdark-darkd
sudo systemctl enable afterdark-darkd
sudo systemctl status afterdark-darkd
\`\`\`

### macOS (launchd)
\`\`\`bash
sudo launchctl load /Library/LaunchDaemons/com.afterdarksys.darkd.plist
sudo launchctl unload /Library/LaunchDaemons/com.afterdarksys.darkd.plist
\`\`\`

### Windows
\`\`\`powershell
Start-Service afterdark-darkd
Stop-Service afterdark-darkd
Get-Service afterdark-darkd
\`\`\`

## Source Repositories

- [afterdark-darkd](https://github.com/afterdarksys/afterdark-darkd)
- [darkd-rk-linuxmalware](https://github.com/afterdarksys/darkd-rk-linuxmalware)
- [darkd-clamav-plugin](https://github.com/afterdarksys/darkd-clamav-plugin)

## License

MIT License - See individual repositories for details.
README

    log_success "README generated"
}

# Clean build artifacts
clean_all() {
    log_info "Cleaning build artifacts..."

    rm -rf "$BINARIES_DIR"

    # Clean individual repos
    for repo in "$DARKD_REPO" "$SCANNER_REPO" "$CLAMAV_REPO"; do
        if [ -d "$repo" ]; then
            (cd "$repo" && rm -rf bin/ build/ 2>/dev/null || true)
        fi
    done

    log_success "Clean complete"
}

# Parse arguments
TARGET_ARCH=""
BUILD_COMPONENT="all"
SKIP_CGO="false"
VERBOSE="false"
COMMAND="build"

while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--arch)
            TARGET_ARCH="$2"
            shift 2
            ;;
        -c|--component)
            BUILD_COMPONENT="$2"
            shift 2
            ;;
        -s|--skip-cgo)
            SKIP_CGO="true"
            shift
            ;;
        -v|--verbose)
            VERBOSE="true"
            set -x
            shift
            ;;
        -h|--help|help)
            usage
            exit 0
            ;;
        clone|pull|build|clean|install)
            COMMAND="$1"
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Main execution
print_banner

case "$COMMAND" in
    clone)
        clone_repos
        ;;
    pull)
        pull_repos
        ;;
    build)
        build_all
        ;;
    clean)
        clean_all
        ;;
    install)
        log_info "Installing from $BINARIES_DIR..."
        case "$(uname -s)" in
            Linux)
                "$BINARIES_DIR/scripts/install-linux.sh"
                ;;
            Darwin)
                "$BINARIES_DIR/scripts/install-macos.sh"
                ;;
            *)
                log_error "Use install-windows.ps1 for Windows installation"
                exit 1
                ;;
        esac
        ;;
    *)
        usage
        exit 1
        ;;
esac
