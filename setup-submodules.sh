#!/bin/bash
#
# Alternative setup using git submodules
# This allows: git pull --recurse-submodules to update everything
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Setting up git submodules..."

# Initialize git repo if needed
if [ ! -d .git ]; then
    git init
fi

# Add submodules (pointing to parent directory siblings)
# Note: These use relative paths for portability

# Check if submodules already exist
if [ ! -f .gitmodules ] || ! grep -q "afterdark-darkd" .gitmodules 2>/dev/null; then
    echo "Adding afterdark-darkd submodule..."
    git submodule add https://github.com/afterdarksys/afterdark-darkd.git components/afterdark-darkd
fi

if [ ! -f .gitmodules ] || ! grep -q "darkd-rk-linuxmalware" .gitmodules 2>/dev/null; then
    echo "Adding darkd-rk-linuxmalware submodule..."
    git submodule add https://github.com/afterdarksys/darkd-rk-linuxmalware.git components/darkd-rk-linuxmalware
fi

if [ ! -f .gitmodules ] || ! grep -q "darkd-clamav-plugin" .gitmodules 2>/dev/null; then
    echo "Adding darkd-clamav-plugin submodule..."
    git submodule add https://github.com/afterdarksys/darkd-clamav-plugin.git components/darkd-clamav-plugin
fi

echo "Initializing submodules..."
git submodule update --init --recursive

echo ""
echo "Submodules setup complete!"
echo ""
echo "Directory structure:"
echo "  components/"
echo "    afterdark-darkd/"
echo "    darkd-rk-linuxmalware/"
echo "    darkd-clamav-plugin/"
echo ""
echo "To update all submodules: git pull --recurse-submodules"
echo "Or: git submodule update --remote"
