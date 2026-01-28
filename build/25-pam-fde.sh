#!/usr/bin/bash

set -eoux pipefail

###############################################################################
# PAM FDE Boot Password Module Build Script
###############################################################################
# This script compiles and installs pam_fde_boot_pw.so from source
# Source: https://git.sr.ht/~kennylevinsen/pam_fde_boot_pw
#
# Purpose: Enables automatic GNOME Keyring unlock for LUKS encrypted systems
# - Retrieves LUKS password from systemd's boot password mechanism
# - Injects it into gnome-keyring during PAM session setup
# - Works for systems where LUKS password differs from login password
###############################################################################

echo "::group:: Install Build Dependencies"

# Install build tools and dependencies
dnf5 install -y \
    meson \
    ninja-build \
    gcc \
    pkg-config \
    pam-devel \
    systemd-devel \
    keyutils-libs-devel

echo "::endgroup::"

echo "::group:: Build pam_fde_boot_pw"

# Create temporary build directory
BUILD_DIR=$(mktemp -d)
cd "$BUILD_DIR"

# Clone the repository
# Using specific commit from NixOS package definition (2025-02-14)
git clone https://git.sr.ht/~kennylevinsen/pam_fde_boot_pw
cd pam_fde_boot_pw
git checkout 49bf498fd8d13f73e4a24221818a8a5d2af20088

# Configure with meson
# Note: meson will auto-detect the correct libdir (/usr/lib or /usr/lib64)
meson setup build --prefix=/usr

# Build
meson compile -C build

# Install
meson install -C build

echo "::endgroup::"

echo "::group:: Create Cross-Architecture Symlinks"

# Ensure the module is accessible from both /usr/lib/security and /usr/lib64/security
# This handles cross-architecture compatibility
if [ -f /usr/lib64/security/pam_fde_boot_pw.so ] && [ ! -f /usr/lib/security/pam_fde_boot_pw.so ]; then
    # On x86_64: module is in /usr/lib64, create symlink in /usr/lib
    mkdir -p /usr/lib/security
    ln -sf /usr/lib64/security/pam_fde_boot_pw.so /usr/lib/security/pam_fde_boot_pw.so
    echo "Created symlink: /usr/lib/security/pam_fde_boot_pw.so -> /usr/lib64/security/pam_fde_boot_pw.so"
elif [ -f /usr/lib/security/pam_fde_boot_pw.so ] && [ ! -f /usr/lib64/security/pam_fde_boot_pw.so ]; then
    # On other architectures: module is in /usr/lib, create symlink in /usr/lib64
    mkdir -p /usr/lib64/security
    ln -sf /usr/lib/security/pam_fde_boot_pw.so /usr/lib64/security/pam_fde_boot_pw.so
    echo "Created symlink: /usr/lib64/security/pam_fde_boot_pw.so -> /usr/lib/security/pam_fde_boot_pw.so"
fi

echo "::endgroup::"

echo "::group:: Set SELinux Contexts"

# Restore SELinux contexts for the installed PAM module
# This ensures the module has the correct security labels for Fedora/SELinux
if command -v restorecon &> /dev/null; then
    echo "Restoring SELinux contexts for PAM module..."
    restorecon -v /usr/lib*/security/pam_fde_boot_pw.so 2>/dev/null || true
    echo "✓ SELinux contexts restored"
else
    echo "⚠ restorecon not available, skipping SELinux context restoration"
    echo "  (This is normal in container builds - contexts will be set at runtime)"
fi

echo "::endgroup::"

echo "::group:: Verify Installation"

# Verify the module was installed correctly
if [ -f /usr/lib/security/pam_fde_boot_pw.so ] || [ -f /usr/lib64/security/pam_fde_boot_pw.so ]; then
    echo "✓ pam_fde_boot_pw.so installed successfully"
    ls -la /usr/lib*/security/pam_fde_boot_pw.so
    
    # Show SELinux context if available
    if command -v ls &> /dev/null; then
        echo ""
        echo "SELinux contexts:"
        ls -Z /usr/lib*/security/pam_fde_boot_pw.so 2>/dev/null || echo "  (Not available in container build)"
    fi
else
    echo "✗ ERROR: pam_fde_boot_pw.so not found in expected locations"
    exit 1
fi

echo "::endgroup::"

# Clean up build directory
cd /
rm -rf "$BUILD_DIR"

echo "pam_fde_boot_pw build and install complete!"
