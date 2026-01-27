#!/usr/bin/env bash

# Tell build process to exit if there are any errors.
set -oue pipefail

###############################################################################
# Install packages from FyraLabs Terra Repository
###############################################################################
# This script enables the FyraLabs Terra repository, installs packages,
# and then disables the repository following Universal Blue/Bluefin conventions.
#
# IMPORTANT CONVENTIONS (from @ublue-os/bluefin):
# - Use dnf5 exclusively (never dnf or yum)
# - Always use -y flag for non-interactive operations
# - Clean up repository files after installation
###############################################################################

echo "Installing packages from FyraLabs Terra..."

# Enable Terra repository using --repofrompath and install terra-release
# The $releasever will be automatically substituted by dnf5
dnf5 install -y --nogpgcheck --repofrompath "terra,https://repos.fyralabs.com/terra\$releasever" terra-release

# Install packages from Terra
dnf5 install -y \
    zed \
    starship \
    yazi

# Disable Terra repository
dnf5 config-manager setopt terra.enabled=0

echo "FyraLabs Terra packages installed successfully"
