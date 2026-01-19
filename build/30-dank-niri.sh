#!/usr/bin/bash

set -eoux pipefail

# Source helper functions
# shellcheck source=build/copr-helpers.sh
source /ctx/build/copr-helpers.sh

# Install Niri (Stable)
# Using yalter/niri COPR
copr_install_isolated "yalter/niri" niri

# Install Dank Material Shell (Stable)
# Using avengemedia/dms COPR. Note that enabling this automatically enables avengemedia/danklinux.
copr_install_isolated "avengemedia/danklinux" cliphist danksearch dgop dms-greeter material-symbols-fonts matugen quickshell
copr_install_isolated "avengemedia/dms" dms

# Enable Greetd
systemctl enable greetd

dnf5 install -y brightnessctl foot gnome-keyring-pam nautilus xdg-user-dirs xdg-terminal-exec
