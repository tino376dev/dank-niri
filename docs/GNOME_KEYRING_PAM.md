# GNOME Keyring PAM Configuration for Greetd

## Problem Statement

When logging in through greetd with dms-greeter, users were being prompted to unlock the GNOME keyring despite having successfully authenticated. This creates a poor user experience as users have to enter their password twice - once at the greeter and again to unlock the keyring.

## Root Cause

The GNOME keyring auto-unlock feature relies on PAM (Pluggable Authentication Modules) to capture the user's login password and use it to unlock the keyring. The order and placement of PAM modules is critical for this functionality to work correctly.

### Why Order Matters

1. **Password Capture**: `pam_gnome_keyring.so` needs to see the plaintext password during authentication
2. **System Authentication**: The system needs to verify the password is correct first via `system-login`
3. **Session Setup**: The keyring daemon needs to be started with the unlocked keyring

### The Original (Broken) Configuration

```pam
# Authentication
auth    optional    pam_gnome_keyring.so
auth    include     system-login
```

**Problem**: The keyring module ran BEFORE `system-login`, so it didn't have access to the validated password.

### The Fixed Configuration

```pam
# Authentication
auth       include      system-login
auth       optional     pam_gnome_keyring.so

# Password management
password   optional     pam_gnome_keyring.so
password   include      system-login

# Session management
session    include      system-login
session    optional     pam_gnome_keyring.so auto_start
```

**Why This Works**:

1. **Auth Phase**:
   - `system-login` validates the password first
   - `pam_gnome_keyring.so` captures the validated password to unlock the keyring

2. **Password Phase**:
   - Added `pam_gnome_keyring.so` to update keyring password when user changes login password
   - This keeps the keyring password in sync with the login password

3. **Session Phase**:
   - `system-login` sets up the session
   - `pam_gnome_keyring.so auto_start` ensures the keyring daemon starts and unlocks

## How GNOME Keyring Auto-Unlock Works

1. User enters password at greeter
2. PAM `system-login` validates the password against the system
3. If validation succeeds, `pam_gnome_keyring.so` receives the password
4. The keyring module attempts to unlock the default keyring using this password
5. If the keyring password matches the login password, the keyring unlocks automatically
6. Session starts with `pam_gnome_keyring.so auto_start` launching the daemon
7. User's session has an unlocked keyring, no additional prompts needed

## Important Notes

### The `optional` Flag

All `pam_gnome_keyring.so` entries use the `optional` control flag:
- Authentication continues even if keyring unlock fails
- Prevents login failures if the keyring doesn't exist or has a different password
- Allows system to remain usable even if keyring has issues

### First Login

On first login, the keyring may not exist:
1. User logs in successfully
2. GNOME Keyring daemon creates a default keyring
3. The keyring password is automatically set to the login password
4. Subsequent logins will unlock automatically

### Password Mismatch

If the keyring password differs from the login password:
1. User will be prompted to unlock the keyring
2. User should:
   - Either enter the old keyring password
   - Or delete `~/.local/share/keyrings/` to reset the keyring
3. After reset, the keyring will sync with the new login password

## Testing the Fix

To verify the fix works:

1. Build and deploy the updated image
2. Boot the system and reach the greeter
3. Log in with valid credentials
4. Verify that no keyring unlock prompt appears
5. Check that applications using the keyring (browsers, password managers) work without prompts

## Related Components

This PAM configuration works in conjunction with:
- **gnome-keyring-pam**: Provides `pam_gnome_keyring.so`
- **gnome-keyring**: The keyring daemon and storage
- **greetd**: The display manager service
- **dms-greeter**: The greeter interface

Installed via build script (`build/30-dank-niri.sh`):
```bash
dnf install -y gnome-keyring-pam
```

**CRITICAL**: The gnome-keyring daemon is started by PAM's `auto_start` flag, NOT by systemd. Enabling `gnome-keyring-daemon.service` via systemd creates a race condition where the daemon starts in a locked state before PAM can unlock it with the user's password.

## References

- [GNOME Keyring Wiki](https://wiki.gnome.org/Projects/GnomeKeyring)
- [PAM Configuration Documentation](https://linux.die.net/man/5/pam.conf)
- [pam_gnome_keyring Manual](https://linux.die.net/man/8/pam_gnome_keyring)
- [Arch Linux Wiki: GNOME Keyring](https://wiki.archlinux.org/title/GNOME/Keyring)

## Troubleshooting

### Keyring Prompts "As Soon As the Keyring Is Required"

If you can log in successfully but get prompted to unlock the keyring when an application tries to use it:

**Root Cause**: The gnome-keyring-daemon was started by systemd BEFORE PAM could unlock it with your password.

**Solution**:
1. **Disable systemd auto-start of the keyring daemon**:
   ```bash
   systemctl --user disable gnome-keyring-daemon.service
   systemctl --user disable gnome-keyring-daemon.socket
   systemctl --user stop gnome-keyring-daemon.service
   ```

2. **Verify no systemd unit is starting it**:
   ```bash
   systemctl --user status gnome-keyring-daemon.service
   # Should show: "Unit gnome-keyring-daemon.service could not be found."
   ```

3. **Log out and log back in** - PAM will start the daemon with `auto_start` in an unlocked state

**Why This Happens**: When systemd starts the daemon before login, it starts in a locked state. PAM's `auto_start` flag then can't properly initialize it because it's already running.

### Keyring Still Prompts After Fix

1. **Check PAM configuration**:
   ```bash
   cat /etc/pam.d/greetd
   ```
   Verify the order matches the fixed configuration above

2. **Verify gnome-keyring-pam is installed**:
   ```bash
   rpm -q gnome-keyring-pam
   ```

3. **Check that systemd is NOT starting the daemon**:
   ```bash
   systemctl --user is-enabled gnome-keyring-daemon.service 2>/dev/null
   # Should show: "disabled" or "Failed to get unit file state"
   ```

4. **Reset the keyring** (last resort):
   ```bash
   rm -rf ~/.local/share/keyrings/
   ```
   Then log out and log back in

### Keyring Password Mismatch

If you changed your login password but not your keyring password:
```bash
# Delete and recreate keyring
rm -rf ~/.local/share/keyrings/
# Log out and log back in - keyring will sync with new password
```

## Security Considerations

- The keyring password should always match the login password for auto-unlock
- The keyring daemon runs per-user and is isolated
- Keyring data is encrypted at rest
- The `optional` flag ensures failed keyring unlock doesn't prevent login
- Physical access to the machine while logged in provides access to unlocked secrets

## Future Enhancements

Potential improvements:
- Add support for alternative authentication methods (fingerprint, smartcard)
- Implement keyring password reset on password change
- Add support for multiple keyrings
- Integrate with hardware security tokens (YubiKey, etc.)
