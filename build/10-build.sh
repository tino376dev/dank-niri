#!/usr/bin/bash

set -eoux pipefail

###############################################################################
# Main Build Script
###############################################################################
# This script follows the @ublue-os/bluefin pattern for build scripts.
# It uses set -eoux pipefail for strict error handling and debugging.
###############################################################################

# Source helper functions
# shellcheck source=/dev/null
source /ctx/build/copr-helpers.sh

echo "::group:: Copy Custom Files"

# Copy Brewfiles to standard location
mkdir -p /usr/share/ublue-os/homebrew/
cp /ctx/custom/brew/*.Brewfile /usr/share/ublue-os/homebrew/

# Consolidate Just Files
mkdir -p /usr/share/ublue-os/just/
find /ctx/custom/ujust -iname '*.just' -exec printf "\n\n" \; -exec cat {} \; >> /usr/share/ublue-os/just/60-custom.just

# Copy Flatpak preinstall files
mkdir -p /etc/flatpak/preinstall.d/
cp /ctx/custom/flatpaks/*.preinstall /etc/flatpak/preinstall.d/

# Copy system configuration files (using -avf to preserve permissions and ownership)
if [ -d /ctx/custom/system_files ]; then
    cp -avf /ctx/custom/system_files/. /
fi

echo "::endgroup::"

echo "::group:: Remove Unwanted Base Image Packages"

# Remove packages inherited from base image that we don't need
dnf5 remove -y \
    firefox \
    tmux

echo "::endgroup::"

echo "::group:: Install Packages"

# Install packages using dnf5
dnf5 install -y \
    alacritty \
    bat \
    brightnessctl \
    cups-pk-helper \
    dbus-tools \
    fd-find \
    fish \
    foot \
    fprintd \
    gcc \
    git-delta \
    gnome-keyring-pam \
    helix \
    i2c-tools \
    kf6-kimageformats \
    micro \
    nautilus \
    openfortivpn \
    podman-compose \
    podman-docker \
    power-profiles-daemon \
    qt5ct \
    qt6ct \
    ripgrep \
    xdg-desktop-portal-gtk \
    xdg-desktop-portal-gnome \
    xdg-terminal-exec \
    xdg-user-dirs \
    zoxide

# Install nushell from Gemfury repository
cat > /etc/yum.repos.d/gemfury-nushell.repo << 'EOF'
[gemfury-nushell]
name=Gemfury Nushell Repo
baseurl=https://yum.fury.io/nushell/
enabled=1
gpgcheck=0
gpgkey=https://yum.fury.io/nushell/gpg.key
EOF

dnf5 -y --setopt=tsflags=noscripts install nushell

# Disable Gemfury repository after install
dnf5 config-manager setopt gemfury-nushell.enabled=0

echo "::endgroup::"

echo "::group:: Install Third-Party Packages"

# Install Tailscale from official repository (Fedora 41+ instructions adapted for dnf5)
dnf5 config-manager addrepo --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo
dnf5 install -y tailscale

# Remove repo file after install to keep bootc image repository state clean
rm -f /etc/yum.repos.d/tailscale.repo

echo "::endgroup::"

echo "::group:: System Configuration"

# Enable/disable systemd services
systemctl enable podman.socket
systemctl enable tailscaled
# Example: systemctl mask unwanted-service

echo "::endgroup::"

echo "Custom build complete!"
