# Upgrade Notes for GNOME Keyring Unlock Fix

## What Was Fixed

This update completes the implementation of automatic GNOME Keyring unlock for LUKS encrypted systems. The previous attempt (commit 48d6791) updated the PAM configuration and documentation but was missing the critical build script that compiles and installs the `pam_fde_boot_pw.so` module.

### Changes Made

1. **Added `build/25-pam-fde.sh`** - New build script that:
   - Installs required build dependencies (meson, gcc, pam-devel, systemd-devel, keyutils-libs-devel)
   - Clones and builds `pam_fde_boot_pw` from https://git.sr.ht/~kennylevinsen/pam_fde_boot_pw
   - Installs the PAM module to `/usr/lib/security/` or `/usr/lib64/security/`
   - Creates cross-architecture symlinks for compatibility

2. **Updated `Containerfile`** - Added execution of `build/25-pam-fde.sh` in the build sequence

3. **Verified PAM Configuration** - Confirmed that `/usr/lib/pam.d/greetd` already has the correct configuration from the previous fix attempt:
   ```pam
   session    optional     /usr/lib/security/pam_fde_boot_pw.so inject_for=gkr
   session    optional     pam_gnome_keyring.so auto_start
   ```

## What This Means for Users

### For New Deployments
- GNOME Keyring will automatically unlock with your LUKS password or login password
- No additional configuration needed
- Works out of the box

### For Existing Users Upgrading

After upgrading to this version (via `bootc upgrade` or rebase), you'll need to reset your keyring to use the new automatic unlock feature:

```bash
# 1. Delete your existing keyring (BACKUP PASSWORDS FIRST if needed!)
rm -rf ~/.local/share/keyrings/

# 2. Log out completely
# 3. Log back in

# Your keyring will be created automatically with the correct password
# For LUKS users: keyring password = LUKS password
# For non-LUKS users: keyring password = login password
```

### How to Verify It's Working

After upgrading and resetting your keyring:

```bash
# 1. Check if the PAM module is installed
ls -la /usr/lib/security/pam_fde_boot_pw.so
ls -la /usr/lib64/security/pam_fde_boot_pw.so  # On x86_64 systems

# 2. Check if it's in the PAM configuration
grep "pam_fde_boot_pw" /usr/lib/pam.d/greetd

# 3. Test login
# - Log out and log back in
# - You should NOT see a keyring unlock prompt
# - Applications should access the keyring without prompting
```

## Troubleshooting

### Still Getting Keyring Prompts?

1. **Verify the module is installed:**
   ```bash
   ls -la /usr/lib*/security/pam_fde_boot_pw.so
   ```
   Should show the file exists in at least one location.

2. **Check PAM configuration:**
   ```bash
   cat /usr/lib/pam.d/greetd
   ```
   Should include the `pam_fde_boot_pw.so inject_for=gkr` line.

3. **Remove old PAM config if it exists:**
   ```bash
   # Check if old config exists in /etc
   ls -la /etc/pam.d/greetd
   
   # If it exists, remove it (our config is in /usr/lib/pam.d/ now)
   sudo rm /etc/pam.d/greetd
   
   # Reboot for changes to take effect
   sudo reboot
   ```

4. **Reset keyring again:**
   ```bash
   rm -rf ~/.local/share/keyrings/
   # Log out and back in
   ```

### For LUKS Users with Different Login/LUKS Passwords

If your login password is different from your LUKS password, `pam_fde_boot_pw` will inject your LUKS password into the keyring. After resetting your keyring, it will be created with your LUKS password.

**Important**: Applications will need your LUKS password to unlock the keyring, not your login password.

**Alternative**: You can set your login password to match your LUKS password to avoid confusion.

## Additional Documentation

For complete details about GNOME Keyring PAM integration, LUKS FDE support, and troubleshooting, see:

- [`docs/GNOME_KEYRING_PAM.md`](GNOME_KEYRING_PAM.md) - Complete technical documentation

## Related Issues

This fix resolves the issue where users were prompted to unlock the GNOME keyring after logging in, despite having authenticated successfully. The root cause was that the build script to compile and install `pam_fde_boot_pw.so` was never created, even though the PAM configuration referenced it.

---

**Date**: 2026-01-28  
**Commit**: feat: add pam_fde_boot_pw module for LUKS keyring unlock  
**Branch**: copilot/fix-gnome-keyring-unlock-again
