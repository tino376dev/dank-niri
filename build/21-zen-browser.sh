#!/usr/bin/env bash

# Tell build process to exit if there are any errors.
set -oue pipefail

###############################################################################
# Install Zen Browser from COPR
###############################################################################
# This script installs Zen Browser from the scottames/zen-browser COPR
# repository following Universal Blue/Bluefin conventions.
#
# IMPORTANT CONVENTIONS (from @ublue-os/bluefin):
# - Use dnf5 exclusively (never dnf or yum)
# - Always use -y flag for non-interactive operations
# - Use copr_install_isolated pattern to avoid repo persistence
###############################################################################

# Source helper functions
# shellcheck source=/dev/null
source /ctx/build/copr-helpers.sh

echo "Installing Zen Browser from COPR scottames/zen-browser..."

# Install Zen Browser using the isolated COPR pattern
copr_install_isolated "scottames/zen-browser" zen-browser

echo "Zen Browser installed successfully"
