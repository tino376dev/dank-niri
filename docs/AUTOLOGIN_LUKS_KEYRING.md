# Autologin with LUKS Keyring Unlock

This guide explains how to enable autologin with automatic GNOME keyring unlock using your LUKS encryption password.

## Overview

When you have:
- LUKS full disk encryption
- Autologin enabled (no password prompt at greeter)
- GNOME keyring for storing passwords and secrets

The keyring normally cannot be unlocked because autologin skips the password prompt. This feature uses the LUKS password stored in the kernel keyring to automatically unlock the GNOME keyring.

## How It Works

1. **At Boot**: You enter your LUKS password to decrypt the disk
2. **Kernel Keyring**: The LUKS password is temporarily stored in the kernel keyring
3. **Autologin**: Greetd automatically logs you in without a password prompt
4. **Keyring Unlock**: A PAM script retrieves the LUKS password from the kernel keyring and unlocks the GNOME keyring
5. **Session Start**: Your session starts with the keyring already unlocked

## Prerequisites

**CRITICAL**: This only works if your LUKS password **matches** your user password.

If they don't match, you must either:
- **Option A**: Change your user password to match your LUKS password
- **Option B**: Change your LUKS password to match your user password  
- **Option C**: Reset your keyring to use your current user password

### Checking if Passwords Match

To verify if your passwords match:
```bash
# This will prompt for your user password
# If it's the same as your LUKS password, the keyring will unlock automatically
gnome-keyring-daemon --unlock
# Press Ctrl+C after entering password
```

### Resetting Keyring to Match User Password

If you want to reset your keyring to use your current user password:

```bash
# CAUTION: This deletes your existing keyring!
# Export passwords from your browser/apps first if needed
rm -rf ~/.local/share/keyrings/

# Log out and log back in
# A new keyring will be created with your current user password
```

## Enabling Autologin

### Step 1: Configure Greetd for Autologin

Edit the greetd configuration:

```bash
sudo micro /etc/greetd/config.toml
```

Add or modify the `[initial_session]` section:

```toml
[initial_session]
user = "yourusername"  # Replace with your actual username
command = "niri"       # Or "dms-session -- niri" if using DMS
```

**Alternatively**, copy the example configuration:

```bash
# Edit the username in the file first
sudo micro /usr/share/doc/dank-niri/config.toml.autologin
# Then copy it
sudo cp /usr/share/doc/dank-niri/config.toml.autologin /etc/greetd/config.toml
```

### Step 2: Enable PAM Configuration for Autologin

Replace the default PAM configuration with the autologin version:

```bash
sudo cp /usr/share/doc/dank-niri/greetd-autologin /usr/lib/pam.d/greetd
```

This PAM configuration:
- Allows login without password prompt (`pam_permit.so`)
- Runs the unlock script to retrieve LUKS password from kernel keyring
- Unlocks the GNOME keyring with that password
- Starts the session with the keyring unlocked

### Step 3: Reboot

```bash
sudo reboot
```

After reboot, you should:
1. Enter your LUKS password to decrypt the disk
2. Be automatically logged in without a greeter prompt
3. Have your GNOME keyring automatically unlocked

## Verifying It Works

After enabling autologin and rebooting:

1. **Check if you were logged in automatically** - You should see your desktop without a login prompt

2. **Check if keyring is unlocked** - Open an app that uses the keyring (browser, password manager) and verify you don't get prompted to unlock

3. **Check system logs** for the unlock script:
   ```bash
   journalctl -t unlock-gnome-keyring-luks -b
   ```

   You should see messages like:
   ```
   unlock-gnome-keyring-luks: Starting GNOME keyring unlock from LUKS password
   unlock-gnome-keyring-luks: Found LUKS password in kernel keyring (key: cryptsetup)
   unlock-gnome-keyring-luks: Successfully unlocked GNOME keyring for user USERNAME
   ```

## Disabling Autologin

If you want to disable autologin and go back to the normal greeter:

### Step 1: Remove Autologin from Greetd Config

Edit greetd configuration:
```bash
sudo micro /etc/greetd/config.toml
```

Remove or comment out the `[initial_session]` section:
```toml
# [initial_session]
# user = "yourusername"
# command = "niri"
```

### Step 2: Restore Normal PAM Configuration

```bash
sudo cp /usr/lib/pam.d/greetd.backup /usr/lib/pam.d/greetd
```

Or manually restore the default configuration that uses `pam_gnome_keyring.so` with password authentication.

### Step 3: Reboot

```bash
sudo reboot
```

You'll now see the greeter and need to enter your password to log in.

## Security Considerations

### When to Use Autologin

**Safe scenarios:**
- Single-user home systems with LUKS encryption
- Systems with physical security (locked room, etc.)
- Development/testing environments

**Unsafe scenarios:**
- Multi-user systems
- Laptops that might be left unattended
- Systems in public or shared spaces
- Work computers with compliance requirements

### Security Implications

**With autologin enabled:**
- ✅ Disk is still encrypted (requires LUKS password at boot)
- ✅ Keyring is unlocked automatically
- ❌ No login screen - anyone who can boot the system can access your session
- ❌ Physical access to the boot process = access to your session

**Without autologin (normal greeter):**
- ✅ Disk is encrypted (requires LUKS password at boot)
- ✅ Login screen requires password
- ✅ Two layers of authentication (LUKS + login)

### Best Practices

1. **Only use on single-user systems** where you're the only person with physical access
2. **Enable screen locking** - Set up automatic screen lock after inactivity
3. **Keep LUKS and user passwords in sync** - If you change one, change the other
4. **Have a backup plan** - Know how to disable autologin if needed (boot from USB, etc.)

## Troubleshooting

### Autologin Works but Keyring is Still Locked

**Symptom**: You're logged in automatically but apps still prompt for keyring unlock.

**Possible causes:**
1. LUKS password doesn't match user/keyring password
2. Kernel keyring doesn't contain the LUKS password
3. PAM script failed to run

**Solutions:**

Check the logs:
```bash
journalctl -t unlock-gnome-keyring-luks -b
```

If you see "Could not retrieve LUKS password from kernel keyring":
- Your system may not be storing the LUKS password in the kernel keyring
- Check if you're using systemd-cryptsetup or another method

If you see "Failed to unlock GNOME keyring (password may not match)":
- Your keyring password doesn't match your LUKS password
- Reset your keyring: `rm -rf ~/.local/share/keyrings/` and log in again

### Autologin Doesn't Work at All

**Symptom**: You still see the greeter after reboot.

**Solutions:**

1. Check greetd configuration:
   ```bash
   cat /etc/greetd/config.toml
   ```
   Verify `[initial_session]` section exists with correct username

2. Check greetd logs:
   ```bash
   journalctl -u greetd -b
   ```

3. Verify PAM configuration is in place:
   ```bash
   cat /usr/lib/pam.d/greetd
   ```

### System Won't Boot After Enabling Autologin

**Symptom**: System hangs or drops to emergency mode.

**Solution**: Boot from a live USB and:

1. Mount your root partition
2. Remove the autologin PAM config:
   ```bash
   sudo rm /path/to/mounted/root/usr/lib/pam.d/greetd
   ```
3. Or reset greetd config:
   ```bash
   sudo rm /path/to/mounted/root/etc/greetd/config.toml
   ```
4. Reboot

### Keyring Unlocks Sometimes but Not Always

**Symptom**: Inconsistent behavior - sometimes the keyring is unlocked, sometimes not.

**Possible cause**: Timing issue - the unlock script may be running before the keyring is ready.

**Solution**: This is a known limitation. The script already exits gracefully if the keyring doesn't exist yet. Check logs to see what's happening.

### Want to Unlock Keyring but Keep Normal Login

If you want to keep the normal greeter (with password) but still have automatic keyring unlock, **don't use this guide**. The standard PAM configuration already handles automatic keyring unlock when you enter your password at the greeter.

This feature is specifically for **autologin** (skipping the greeter entirely).

## Technical Details

### Files Involved

- **PAM Configuration**: `/usr/lib/pam.d/greetd`
  - Autologin version: `/usr/share/doc/dank-niri/greetd-autologin`
  - Uses `pam_permit.so` for passwordless auth
  - Calls unlock script via `pam_exec.so`

- **Unlock Script**: `/usr/libexec/unlock-gnome-keyring-luks`
  - Reads LUKS password from kernel keyring
  - Unlocks GNOME keyring using that password
  - Logs to systemd journal

- **Greetd Config**: `/etc/greetd/config.toml`
  - Example: `/usr/share/doc/dank-niri/config.toml.autologin`
  - Sets `[initial_session]` for autologin

### How the Unlock Script Works

1. PAM calls the script during session setup
2. Script checks for `PAM_USER` environment variable
3. Attempts to read LUKS password from kernel keyring using `keyctl`
4. Tries multiple key descriptions: `cryptsetup`, `user-crypto`, etc.
5. If found, pipes password to `gnome-keyring-daemon --unlock`
6. Logs success/failure to systemd journal
7. Always exits 0 to never block login

### Kernel Keyring Storage

The LUKS password is stored in the kernel keyring by:
- `systemd-cryptsetup` - During boot when unlocking LUKS volumes
- Stored with description "cryptsetup" in the user keyring
- Accessible by root and the key owner
- Temporary - cleared on reboot

## References

- [Arch Wiki: Greetd - Unlocking keyring on autologin](https://wiki.archlinux.org/title/Greetd#Unlocking_keyring_on_autologin_using_the_cryptsetup_password)
- [GNOME Keyring PAM Integration](https://wiki.gnome.org/Projects/GnomeKeyring/Pam)
- [Linux PAM Documentation](https://www.linux-pam.org/)
- [Kernel Keyring Documentation](https://www.kernel.org/doc/html/latest/security/keys/core.html)
