#!/usr/bin/bash

set -eoux pipefail

###############################################################################
# Build and Install pam_fde_boot_pw
###############################################################################
# This module enables automatic GNOME Keyring unlock for LUKS FDE users
# by injecting the LUKS password from systemd into gnome-keyring.
#
# Required for users where LUKS password ≠ login password
# Source: https://git.sr.ht/~kennylevinsen/pam_fde_boot_pw
###############################################################################

echo "::group:: Build and Install pam_fde_boot_pw"

# Install build dependencies
dnf5 install -y \
    git \
    meson \
    ninja-build \
    pam-devel \
    systemd-devel \
    keyutils-libs-devel

# Clone and build
cd /tmp
git clone https://git.sr.ht/~kennylevinsen/pam_fde_boot_pw
cd pam_fde_boot_pw

# Build and install
# Use --prefix=/usr to install to /usr/lib/security instead of /usr/local/lib/security
# This avoids issues with /usr/local being a symlink in ostree/bootc systems
meson setup build --prefix=/usr
ninja -C build
ninja -C build install

# Verify installation (check lib64 on x86_64 systems, lib on others)
if [ -f /usr/lib64/security/pam_fde_boot_pw.so ]; then
    echo "pam_fde_boot_pw.so installed successfully to /usr/lib64/security/"
elif [ -f /usr/lib/security/pam_fde_boot_pw.so ]; then
    echo "pam_fde_boot_pw.so installed successfully to /usr/lib/security/"
else
    echo "ERROR: pam_fde_boot_pw.so was not installed correctly"
    exit 1
fi

# Clean up build artifacts
cd /
rm -rf /tmp/pam_fde_boot_pw

# Remove build-only dependencies (keep runtime deps: pam, systemd, keyutils-libs)
# Note: We don't remove 'git' as it may be preinstalled in the base image
dnf5 remove -y \
    meson \
    ninja-build \
    pam-devel \
    systemd-devel \
    keyutils-libs-devel

echo "::endgroup::"

echo "pam_fde_boot_pw build complete!"
