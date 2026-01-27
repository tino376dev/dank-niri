#!/usr/bin/env bash

# Tell build process to exit if there are any errors.
set -oue pipefail

###############################################################################
# Microsoft Applications Installation
###############################################################################
# This script installs Microsoft Edge and VS Code Insiders from official
# Microsoft repositories following Universal Blue/Bluefin conventions.
#
# IMPORTANT CONVENTIONS (from @ublue-os/bluefin):
# - Always disable repositories after installation (atomic immutability)
# - Use dnf5 exclusively (never dnf or yum)
# - Always use -y flag for non-interactive operations
# - Remove repo files to keep the image clean (repos don't work at runtime)
###############################################################################

echo "Installing Microsoft applications..."

# Import Microsoft GPG signing key
echo "Importing Microsoft GPG key..."
rpm --import https://packages.microsoft.com/keys/microsoft.asc

### Install Microsoft Edge
echo "Installing Microsoft Edge..."

# Add Microsoft Edge repository
dnf5 config-manager addrepo --from-repofile=https://packages.microsoft.com/yumrepos/edge/config.repo --save-filename=microsoft-edge

# Install Microsoft Edge
dnf5 install -y microsoft-edge-stable

# Remove repo file (required - repos don't work at runtime in bootc images)
rm -f /etc/yum.repos.d/microsoft-edge.repo

echo "Microsoft Edge installed successfully"

### Install VS Code Insiders
echo "Installing VS Code Insiders..."

# Add VS Code repository
dnf5 config-manager addrepo --from-repofile=https://packages.microsoft.com/yumrepos/vscode/config.repo --save-filename=vscode

# Install VS Code Insiders
dnf5 install -y code-insiders

# Remove repo file (required - repos don't work at runtime in bootc images)
rm -f /etc/yum.repos.d/vscode.repo

echo "VS Code Insiders installed successfully"
echo "Microsoft applications installation complete!"
