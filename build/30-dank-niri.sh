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

dnf install -y brightnessctl foot gnome-keyring-pam micro nautilus openfortivpn power-profiles-daemon xdg-user-dirs xdg-terminal-exec

# Create greeter system user (REQUIRED for dms-greeter to work)
# This resolves the tmpfiles.d error: "failed to resolve user greeter: no such process"
tee /usr/lib/sysusers.d/greeter.conf <<'EOF'
g greeter 767
u greeter 767 "Greetd greeter"
EOF

# Note: greetd PAM configuration with gnome-keyring integration is provided in custom/system_files/etc/pam.d/greetd
