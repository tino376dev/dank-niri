# Upgrade Notes for GNOME Keyring Unlock Fix

## What Was Fixed

This update implements standard PAM integration for automatic GNOME Keyring unlock.

### Changes Made

1. **Updated PAM Configuration** - `/usr/lib/pam.d/greetd` now includes:
   ```pam
   auth       optional     pam_gnome_keyring.so
   password   optional     pam_gnome_keyring.so
   session    optional     pam_gnome_keyring.so auto_start
   ```
   Combined with `include system-login`, this provides automatic keyring unlock using your login password.

## What This Means for Users

### For New Deployments
- GNOME Keyring will automatically unlock with your login password
- No additional configuration needed
- Works out of the box

### For Existing Users Upgrading

After upgrading to this version (via `bootc upgrade` or rebase), you'll need to reset your keyring:

```bash
# 1. Delete your existing keyring (BACKUP PASSWORDS FIRST if needed!)
rm -rf ~/.local/share/keyrings/

# 2. Log out completely
# 3. Log back in

# Your keyring will be created automatically with your login password
```

### How to Verify It's Working

After upgrading and resetting your keyring:

```bash
# 1. Check PAM configuration
cat /usr/lib/pam.d/greetd
# Should show pam_gnome_keyring.so in auth, password, and session sections

# 2. Test login
# - Log out and log back in
# - You should NOT see a keyring unlock prompt
# - Applications should access the keyring without prompting
```

## Troubleshooting

### Still Getting Keyring Prompts?

1. **Check PAM configuration:**
   ```bash
   cat /usr/lib/pam.d/greetd
   ```
   Should include `pam_gnome_keyring.so` lines.

2. **Remove old PAM config if it exists:**
   ```bash
   # Check if old config exists in /etc
   ls -la /etc/pam.d/greetd
   
   # If it exists, remove it (our config is in /usr/lib/pam.d/ now)
   sudo rm /etc/pam.d/greetd
   
   # Reboot for changes to take effect
   sudo reboot
   ```

3. **Reset keyring again:**
   ```bash
   rm -rf ~/.local/share/keyrings/
   # Log out and back in
   ```

### For LUKS Users

If your login password is different from your LUKS password:

**The keyring will use your login password, not your LUKS password.**

Options:
1. **Set login password to match LUKS password** - Simplest approach
2. **Use a password manager** - Store LUKS password in the keyring
3. **Accept entering keyring password separately** - If you prefer different passwords

## Additional Documentation

For complete details about GNOME Keyring PAM integration and troubleshooting, see:

- [`docs/GNOME_KEYRING_PAM.md`](GNOME_KEYRING_PAM.md) - Complete technical documentation
- [`docs/SELINUX_PAM.md`](SELINUX_PAM.md) - SELinux-specific information for Fedora

## Related Issues

This fix resolves the issue where users were prompted to unlock the GNOME keyring after logging in, despite having authenticated successfully. The solution uses standard PAM integration with gnome-keyring.

---

**Date**: 2026-01-28  
**Changes**: Simplified to standard PAM integration (removed FDE boot password module)  
**Branch**: copilot/fix-gnome-keyring-unlock-again
