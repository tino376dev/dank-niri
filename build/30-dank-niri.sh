#!/usr/bin/bash

set -eoux pipefail

# Source helper functions
source /ctx/build/copr-helpers.sh

echo "::group:: Remove GNOME Desktop"

# Remove GNOME Shell and related packages
dnf5 remove -y \
    gnome-shell \
    gnome-shell-extension* \
    gnome-terminal \
    gnome-software \
    gnome-control-center \
    gdm

echo "GNOME desktop removed"
echo "::endgroup::"

echo "::group:: Install Dank Material Shell and Niri"

# Install Niri (Stable)
# Using yalter/niri COPR
copr_install_isolated "yalter/niri" \
    niri \
    xdg-desktop-portal-gnome

# Install Dank Material Shell (Stable)
# Using avengemedia/dms COPR. Note that enabling this automatically enables avengemedia/danklinux.
# The 'dms' package pulls in core dependencies, but we add commonly used utilities and specific user requests here.
# - foot: Terminal (requested)
# - matugen: Theming (often needed if not pulled by dms directly)
# - cliphist: Clipboard history (recommended by docs)
# - wl-clipboard: Clipboard support
# - gnome-keyring: Secrets management
# - polkit-gnome: Privileges
# - playerctl, brightnessctl: Media/HW control
copr_install_isolated "avengemedia/dms" \
    dms \
    dms-cli \
    dms-greeter \
    dgop \
    dsearch \
    foot \
    matugen \
    cliphist \
    wl-clipboard \
    gnome-keyring \
    polkit-gnome \
    playerctl \
    brightnessctl

echo "::endgroup::"

echo "::group:: Configure Session"

# Enable Greetd
systemctl enable greetd

echo "Dank Niri Environment Installed"
echo "::endgroup::"
