# GNOME Keyring PAM Configuration for Greetd

## Standard PAM Integration (Simplified)

**Good news!** This image uses standard PAM integration for automatic GNOME Keyring unlock.

### What's Included

**Updated PAM Configuration** - `/usr/lib/pam.d/greetd` includes:
```pam
auth       optional     pam_gnome_keyring.so
password   optional     pam_gnome_keyring.so
session    optional     pam_gnome_keyring.so auto_start
```

**Note**: PAM config is in `/usr/lib/pam.d/` (not `/etc/pam.d/`) to ensure bootc upgrades properly update it.

### What This Means for You

- ✅ **Standard login**: Keyring unlocks automatically with your login password
- ✅ **LUKS users**: Works if your LUKS password **matches** your login password
- ✅ **No additional setup**: Everything works out of the box
- ✅ **Autologin with LUKS**: See [AUTOLOGIN_LUKS_KEYRING.md](AUTOLOGIN_LUKS_KEYRING.md) for automatic keyring unlock on autologin using your LUKS password

### If You Still Get Keyring Prompts

**First-time users or password changes:**

If you're logging in for the first time or changed your password, reset your keyring:

```bash
# Delete the old keyring
rm -rf ~/.local/share/keyrings/

# Log out and log back in
# Keyring will be created automatically with your current login password
```

For additional troubleshooting, see sections below.

---

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

### The Current Configuration (Fedora-Specific)

**CRITICAL**: On Fedora, greetd must use `system-auth`, not `system-login`.

- **system-login** = For local console logins (getty, login command)
- **system-auth** = For authentication services (display managers, sshd, sudo)

Since greetd is a display manager greeter, it uses `system-auth`:

```pam
# Authentication
auth       substack     system-auth
auth       optional     pam_gnome_keyring.so
auth       include      postlogin

# Account validation
account    required     pam_nologin.so
account    include      system-auth

# Password management
password   optional     pam_gnome_keyring.so
password   include      system-auth

# Session management
session    required     pam_selinux.so close
session    required     pam_loginuid.so
session    optional     pam_keyinit.so force revoke
session    include      system-auth
session    required     pam_selinux.so open
session    optional     pam_gnome_keyring.so auto_start
session    include      postlogin
```

**Why This Works**:

1. **Auth Phase**:
   - `system-auth` validates the password first (using `substack` for proper error handling)
   - `pam_gnome_keyring.so` captures the validated password to unlock the keyring
   - `postlogin` handles post-authentication tasks

2. **Account Phase**:
   - `pam_nologin.so` checks if logins are allowed
   - `system-auth` performs account validation

3. **Password Phase**:
   - `pam_gnome_keyring.so` updates keyring password when user changes login password
   - This keeps the keyring password in sync with the login password

4. **Session Phase**:
   - `pam_selinux.so close` - Prepares SELinux context transition
   - `pam_loginuid.so` - Sets audit UID
   - `pam_keyinit.so` - Initializes kernel keyring
   - `system-auth` - Sets up session (includes pam_systemd, limits, etc.)
   - `pam_selinux.so open` - Sets SELinux context for new session
   - `pam_gnome_keyring.so auto_start` - Starts and unlocks gnome-keyring
   - `postlogin` - Post-session setup tasks

## How GNOME Keyring Auto-Unlock Works

### For Standard Login

1. User enters password at greeter
2. PAM `system-auth` validates the password against the system
3. If validation succeeds, `pam_gnome_keyring.so` receives the password
4. The keyring module attempts to unlock the default keyring using this password
5. If the keyring password matches the login password, the keyring unlocks automatically
6. Session starts with all required modules (`pam_selinux`, `pam_loginuid`, `pam_systemd`, etc.)
7. `pam_gnome_keyring.so auto_start` launches the daemon with unlocked keyring
8. User's session has an unlocked keyring, no additional prompts needed

### For LUKS Encrypted Systems

**Important**: This configuration requires your **login password to match your LUKS password**.

If your login password differs from your LUKS password:
1. **Option A**: Change your login password to match your LUKS password
2. **Option B**: Reset your keyring after login (it will use your login password)

**Note**: The keyring password will be your login password, not your LUKS password.

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

Installed via build scripts:
- `build/10-build.sh`: Installs `gnome-keyring-pam` package

**CRITICAL**: The gnome-keyring daemon is started by PAM's `auto_start` flag, NOT by systemd. Enabling `gnome-keyring-daemon.service` via systemd creates a race condition where the daemon starts in a locked state before PAM can unlock it with the user's password.

### Greetd's Two-Service Architecture

Greetd uses TWO separate PAM services:

1. **`/usr/lib/pam.d/greetd`** - Authenticates the user through the greeter
   - Validates the password
   - Unlocks the keyring
   - **Located in `/usr/lib/pam.d/` to ensure bootc upgrades update it**
   
2. **`/usr/lib/pam.d/greetd-spawn`** - Spawns the user's session
   - Sets up session environment
   - **MUST** also have gnome-keyring session setup

Both services need the gnome-keyring configuration. The `greetd-spawn` service requires:
```pam
auth       include      greetd
account    include      greetd
session    required     pam_env.so conffile=/usr/share/greetd/greetd-spawn.pam_env.conf
session    include      greetd
session    optional     pam_gnome_keyring.so auto_start
```

**CRITICAL**: The `pam_env.so` must be in the **session** phase, not the auth phase. This ensures environment variables (like `XDG_SESSION_TYPE=wayland`) are set correctly when the session starts, which is required for proper gnome-keyring initialization.

This ensures the keyring daemon starts in the session environment with proper access to the unlocked keyring.

## References

- [GNOME Keyring Wiki](https://wiki.gnome.org/Projects/GnomeKeyring)
- [PAM Configuration Documentation](https://linux.die.net/man/5/pam.conf)
- [pam_gnome_keyring Manual](https://linux.die.net/man/8/pam_gnome_keyring)
- [Arch Linux Wiki: GNOME Keyring](https://wiki.archlinux.org/title/GNOME/Keyring)
- [Arch Linux Wiki: GNOME Keyring PAM Integration](https://wiki.archlinux.org/title/GNOME/Keyring#PAM_integration) - See the FDE section if using full disk encryption

## Troubleshooting

### PAM Config Not Updated After bootc Upgrade

**Symptom:** After running `bootc upgrade`, your `/usr/lib/pam.d/greetd` doesn't match the repository, or you see the default Fedora greetd config with `substack system-auth` instead of our custom config.

**Root Cause:** Older versions of this image placed the PAM config in `/etc/pam.d/greetd`. In bootc/ostree systems, `/etc` is persistent and doesn't get replaced during upgrades. If `/etc/pam.d/greetd` exists, PAM will use it instead of `/usr/lib/pam.d/greetd`.

**Solution:**

```bash
# 1. Check if you have the old config in /etc
ls -la /etc/pam.d/greetd

# 2. If it exists, remove it (our config is in /usr/lib/pam.d/greetd now)
sudo rm /etc/pam.d/greetd

# 3. Verify the new config is being used
cat /usr/lib/pam.d/greetd

# 4. Reboot for changes to take effect
sudo reboot
```

After reboot, PAM will use `/usr/lib/pam.d/greetd` which includes the correct gnome-keyring configuration.

**Why This Happened:**
- Early builds: PAM config in `/etc/pam.d/greetd` (persistent, won't update)
- Current builds: PAM config in `/usr/lib/pam.d/greetd` (immutable, updates with image)
- Bootc 3-way merge: If `/etc/pam.d/greetd` exists, it takes precedence

**For Fresh Installs:**
This issue only affects systems that were deployed before the PAM config was moved to `/usr/lib/pam.d/`. Fresh installs will have the correct config automatically.

### LUKS FDE: Keyring Password Mismatch

**Symptom:** You have LUKS encryption and get a keyring unlock prompt after login.

**Root Cause:** Your keyring password doesn't match your login password.

**Solution:**

Reset your keyring to use your login password:

```bash
# 1. Delete the old keyring (backup important passwords first!)
rm -rf ~/.local/share/keyrings/

# 2. Log out completely
# 3. Log back in with your login password

# The keyring will be created automatically with your login password
```

**Important for LUKS Users:**
- The keyring password will be your **login password**, not your LUKS password
- If you want them to match, set your login password to match your LUKS password
- Or use the same password for both LUKS and login from the start

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
   cat /usr/lib/pam.d/greetd
   ```
   Verify the order matches the fixed configuration above
   
   **Note**: If you see a different config, check `/etc/pam.d/greetd` - if it exists, it takes precedence over `/usr/lib/pam.d/greetd` and should be removed.

2. **Check greetd-spawn PAM configuration**:
   ```bash
   cat /usr/lib/pam.d/greetd-spawn
   ```
   Verify it contains:
   ```
   auth       include      greetd
   account    include      greetd
   session    required     pam_env.so conffile=/usr/share/greetd/greetd-spawn.pam_env.conf
   session    include      greetd
    pam-devel \
    systemd-devel \
    keyutils-libs-devel

echo "::endgroup::"
```

The PAM configuration in `custom/system_files/usr/lib/pam.d/greetd` includes the module.

**Important**: The config is in `/usr/lib/pam.d/` (not `/etc/pam.d/`) because in bootc/ostree systems, `/etc` is persistent and doesn't get updated on `bootc upgrade`. Using `/usr/lib/pam.d/` ensures the config updates with the image.

### Standard Login Password Approach

This configuration uses your login password to unlock the keyring. This is the recommended and standard approach:

1. **Set consistent passwords**
   - Use the same password for LUKS encryption and user login (if applicable)
   - This ensures the keyring unlocks automatically
   
2. **Or reset keyring to use login password**
   ```bash
   rm -rf ~/.local/share/keyrings/
   # Log in with your login password
   # Keyring will be created with that password
   ```

3. **Change keyring password to match login password**
   - Open "Passwords and Keys" (Seahorse)
   - Right-click "Login" keyring → Change password
   - Set it to match your login password

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
