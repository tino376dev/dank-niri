# vim: set ft=make :

# Autologin configuration commands

# Enable autologin with LUKS keyring unlock (for single-user systems with LUKS encryption)
[group('System')]
enable-autologin USERNAME:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "⚠️  WARNING: Autologin reduces security!"
    echo "   Only enable on single-user systems with physical security."
    echo ""
    echo "This will:"
    echo "  1. Configure greetd to autologin as user: {{USERNAME}}"
    echo "  2. Enable automatic GNOME keyring unlock using LUKS password"
    echo ""
    echo "Requirements:"
    echo "  - LUKS encryption must be enabled"
    echo "  - Your LUKS password must match your user password"
    echo ""
    read -p "Continue? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 1
    fi
    
    # Backup existing greetd config
    if [ -f /etc/greetd/config.toml ]; then
        echo "Backing up existing greetd config..."
        sudo cp /etc/greetd/config.toml /etc/greetd/config.toml.backup
    fi
    
    # Backup existing PAM config
    if [ -f /usr/lib/pam.d/greetd ]; then
        echo "Backing up existing PAM config..."
        sudo cp /usr/lib/pam.d/greetd /usr/lib/pam.d/greetd.backup
    fi
    
    # Create greetd config with autologin
    echo "Creating greetd configuration for autologin..."
    sudo tee /etc/greetd/config.toml > /dev/null << EOF
    [general]
    service = "greetd-spawn"
    
    [terminal]
    vt = 1
    
    # Default session (fallback if autologin fails)
    [default_session]
    command = "dms-greeter --command niri"
    user = "greeter"
    
    # Autologin session
    [initial_session]
    user = "{{USERNAME}}"
    command = "niri"
    EOF
    
    # Copy PAM config for autologin
    echo "Installing PAM configuration for autologin with keyring unlock..."
    sudo cp /usr/share/doc/dank-niri/greetd-autologin /usr/lib/pam.d/greetd
    
    echo ""
    echo "✅ Autologin enabled for user: {{USERNAME}}"
    echo ""
    echo "Next steps:"
    echo "  1. Ensure your LUKS password matches your user password"
    echo "  2. Reboot: sudo reboot"
    echo ""
    echo "To disable autologin later, run: ujust disable-autologin"

# Disable autologin and restore normal greeter
[group('System')]
disable-autologin:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "Disabling autologin and restoring normal greeter..."
    
    # Restore greetd config from backup
    if [ -f /etc/greetd/config.toml.backup ]; then
        echo "Restoring greetd config from backup..."
        sudo cp /etc/greetd/config.toml.backup /etc/greetd/config.toml
    else
        echo "No backup found, creating default config..."
        sudo tee /etc/greetd/config.toml > /dev/null << 'EOF'
[general]
service = "greetd-spawn"

[terminal]
vt = 1

[default_session]
command = "dms-greeter --command niri"
user = "greeter"
EOF
    fi
    
    # Restore PAM config from backup
    if [ -f /usr/lib/pam.d/greetd.backup ]; then
        echo "Restoring PAM config from backup..."
        sudo cp /usr/lib/pam.d/greetd.backup /usr/lib/pam.d/greetd
    else
        echo "⚠️  Warning: No PAM backup found!"
        echo "You may need to manually restore /usr/lib/pam.d/greetd"
        echo "or redeploy the system to get the default PAM config."
    fi
    
    echo ""
    echo "✅ Autologin disabled. Normal greeter restored."
    echo ""
    echo "Reboot to apply changes: sudo reboot"

# Show autologin status and logs
[group('System')]
autologin-status:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "=== Greetd Configuration ==="
    if [ -f /etc/greetd/config.toml ]; then
        if grep -q "^\[initial_session\]" /etc/greetd/config.toml; then
            echo "Status: ✅ Autologin ENABLED"
            echo ""
            echo "Autologin user:"
            grep "^user = " /etc/greetd/config.toml | grep -v "greeter" || echo "Not found"
        else
            echo "Status: ❌ Autologin DISABLED"
        fi
    else
        echo "Status: ⚠️  No greetd config found"
    fi
    
    echo ""
    echo "=== PAM Configuration ==="
    if [ -f /usr/lib/pam.d/greetd ]; then
        if grep -q "pam_exec.so /usr/libexec/unlock-gnome-keyring-luks" /usr/lib/pam.d/greetd; then
            echo "PAM: ✅ Autologin keyring unlock ENABLED"
        else
            echo "PAM: ❌ Using standard password-based authentication"
        fi
    else
        echo "PAM: ⚠️  No greetd PAM config found"
    fi
    
    echo ""
    echo "=== Recent Keyring Unlock Logs ==="
    journalctl -t unlock-gnome-keyring-luks -b --no-pager -n 20 || echo "No logs found (this is normal if autologin is not enabled or system hasn't rebooted since enabling)"
