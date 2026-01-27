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
cat > /etc/yum.repos.d/microsoft-edge.repo << 'EOF'
[microsoft-edge]
name=Microsoft Edge
baseurl=https://packages.microsoft.com/yumrepos/edge
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

# Install Microsoft Edge
dnf5 install -y microsoft-edge-stable

# Clean up repo file (required - repos don't work at runtime in bootc images)
rm -f /etc/yum.repos.d/microsoft-edge.repo

echo "Microsoft Edge installed successfully"

### Install VS Code Insiders
echo "Installing VS Code Insiders..."

# Add VS Code repository
cat > /etc/yum.repos.d/vscode.repo << 'EOF'
[vscode]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

# Install VS Code Insiders
dnf5 install -y code-insiders

# Clean up repo file (required - repos don't work at runtime in bootc images)
rm -f /etc/yum.repos.d/vscode.repo

echo "VS Code Insiders installed successfully"
echo "Microsoft applications installation complete!"
