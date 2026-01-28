# GNOME Keyring PAM Configuration for Greetd

## LUKS FDE Support (Enabled by Default)

**Good news!** This image now includes automatic GNOME Keyring unlock for LUKS encrypted systems out of the box.

### What's Included

1. **pam_fde_boot_pw.so** - Compiled and installed during image build
   - Retrieves LUKS password from systemd
   - Injects it into gnome-keyring automatically
   - Source: https://git.sr.ht/~kennylevinsen/pam_fde_boot_pw

2. **Updated PAM Configuration** - `/etc/pam.d/greetd` includes:
   ```pam
   session    optional     /usr/lib/security/pam_fde_boot_pw.so inject_for=gkr
   session    optional     pam_gnome_keyring.so auto_start
   ```

### What This Means for You

- ✅ **LUKS users**: Keyring unlocks automatically with your LUKS password
- ✅ **Non-LUKS users**: Standard PAM keyring unlock works as before
- ✅ **No additional setup**: Everything works out of the box

### If You Still Get Keyring Prompts

**First-time users or password changes:**

If you're logging in for the first time or changed your password, reset your keyring:

```bash
# Delete the old keyring
rm -rf ~/.local/share/keyrings/

# Log out and log back in
# Keyring will be created automatically with your current password
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

### The Current Configuration (with LUKS FDE Support)

```pam
# Authentication
auth       include      system-login
auth       optional     pam_gnome_keyring.so

# Password management
password   optional     pam_gnome_keyring.so
password   include      system-login

# Session management
session    include      system-login
session    optional     /usr/lib/security/pam_fde_boot_pw.so inject_for=gkr
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
   - **`pam_fde_boot_pw.so`** retrieves LUKS password from systemd (if present) and injects it
   - `pam_gnome_keyring.so auto_start` ensures the keyring daemon starts and unlocks

## How GNOME Keyring Auto-Unlock Works

### For Non-LUKS Systems (Standard Login)

1. User enters password at greeter
2. PAM `system-login` validates the password against the system
3. If validation succeeds, `pam_gnome_keyring.so` receives the password
4. The keyring module attempts to unlock the default keyring using this password
5. If the keyring password matches the login password, the keyring unlocks automatically
6. Session starts with `pam_gnome_keyring.so auto_start` launching the daemon
7. User's session has an unlocked keyring, no additional prompts needed

### For LUKS Encrypted Systems (FDE)

1. User enters LUKS password at boot → systemd captures it in memory
2. User enters login password at greeter → PAM validates
3. **`pam_fde_boot_pw.so`** retrieves the LUKS password from systemd
4. LUKS password is injected into gnome-keyring as the unlock password
5. If the keyring was created with the LUKS password, it unlocks automatically
6. Session starts with `pam_gnome_keyring.so auto_start` launching the daemon
7. User's session has an unlocked keyring, no additional prompts needed

**Note**: For LUKS systems, the keyring password should match the LUKS password for automatic unlock to work.

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
- **pam_fde_boot_pw**: Provides LUKS password injection for FDE systems

Installed via build scripts:
- `build/10-build.sh`: Installs `gnome-keyring-pam` package
- `build/25-pam-fde.sh`: Compiles and installs `pam_fde_boot_pw.so` to `/usr/local/lib/security/`

**CRITICAL**: The gnome-keyring daemon is started by PAM's `auto_start` flag, NOT by systemd. Enabling `gnome-keyring-daemon.service` via systemd creates a race condition where the daemon starts in a locked state before PAM can unlock it with the user's password.

### Greetd's Two-Service Architecture

Greetd uses TWO separate PAM services:

1. **`/etc/pam.d/greetd`** - Authenticates the user through the greeter
   - Validates the password
   - Unlocks the keyring
   
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

### LUKS FDE: Keyring Prompts After Login

**Symptom:** You have LUKS encryption, you enter password at boot, log in successfully, but then get a keyring unlock prompt.

**Root Cause:** The LUKS password is not being injected into gnome-keyring.

**Solution Options:**

**If Your LUKS Password = Login Password (EASY FIX):**

You DON'T need `pam_fde_boot_pw.so`! Just reset your keyring:

```bash
# 1. Delete the old keyring
rm -rf ~/.local/share/keyrings/

# 2. Log out completely
# 3. Log back in with your password

# The keyring will be created automatically with your login password
# Since login password = LUKS password, everything should work!
```

After this:
- ✅ Login unlocks keyring automatically
- ✅ No more password prompts
- ✅ No additional software needed

**If Your LUKS Password ≠ Login Password:**

**Good News: pam_fde_boot_pw is Already Installed!**

This image includes `pam_fde_boot_pw.so` by default, which automatically injects your LUKS password into gnome-keyring. No additional installation needed!

**To use it:**
1. **Reset your keyring** (if it was created with the wrong password):
   ```bash
   rm -rf ~/.local/share/keyrings/
   ```
2. **Log out and log back in**
3. The keyring will be created and unlocked with your LUKS password automatically

**Verify it's working:**
```bash
# Check if pam_fde_boot_pw is installed (should exist in both locations)
ls -la /usr/lib/security/pam_fde_boot_pw.so
ls -la /usr/lib64/security/pam_fde_boot_pw.so  # On x86_64 systems

# Check if it's in PAM config (should see inject_for=gkr)
grep "pam_fde_boot_pw" /etc/pam.d/greetd
```

**Note:** The build creates symlinks between `/usr/lib/security/` and `/usr/lib64/security/` to ensure the module is accessible regardless of architecture. This cross-architecture compatibility ensures PAM can find the module on all systems.

**Alternative Option: Match Login Password to LUKS Password**
- Change your user login password to match your LUKS password
- Reset the keyring: `rm -rf ~/.local/share/keyrings/`
- Log out and log back in
- Keyring will be created with login password (which matches LUKS)

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
   session    optional     pam_gnome_keyring.so auto_start
   ```
   **CRITICAL**: `pam_env.so` must be in the session phase, NOT the auth phase.

3. **Verify gnome-keyring-pam is installed**:
   ```bash
   rpm -q gnome-keyring-pam
   ```

4. **Check that systemd is NOT starting the daemon**:
   ```bash
   systemctl --user is-enabled gnome-keyring-daemon.service 2>/dev/null
   # Should show: "disabled" or "Failed to get unit file state"
   ```

5. **Reset the keyring** (last resort):
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

## Full Disk Encryption (FDE) Support

### Good News: `pam_fde_boot_pw.so` is Already Installed!

**This image includes automatic LUKS keyring unlock out of the box.**

The `pam_fde_boot_pw.so` module is compiled and installed during the image build process. No additional setup required!

### What This Means for LUKS Users

**If your LUKS password = Login password:**
- ✅ Keyring unlocks automatically
- ✅ No additional configuration needed
- ✅ Just reset your keyring if needed: `rm -rf ~/.local/share/keyrings/`

**If your LUKS password ≠ Login password:**
- ✅ **pam_fde_boot_pw.so is already installed and configured!**
- ✅ Just reset your keyring: `rm -rf ~/.local/share/keyrings/`
- ✅ Log out and log back in
- ✅ Keyring will be created with your LUKS password automatically

### How It Works

`pam_fde_boot_pw.so` is a specialized PAM module that:
- Retrieves the disk decryption password from systemd
- Injects it into GNOME Keyring using `inject_for=gkr` parameter
- Allows automatic keyring unlock using the LUKS password
- Works seamlessly with greetd and PAM

**Current Behavior (With This Image):**
1. 🔓 You enter LUKS password at boot → Disk decrypts → systemd captures password
2. 🚪 You enter login password at greeter → You log in
3. 🔑 `pam_fde_boot_pw.so` retrieves LUKS password from systemd
4. 🔓 GNOME Keyring unlocks automatically with LUKS password
5. ✅ No password prompt!

### LUKS Full Disk Encryption - Technical Details

**Understanding the Problem (Without pam_fde_boot_pw):**
- LUKS password is captured by systemd during boot
- But it's not automatically passed to gnome-keyring
- `pam_gnome_keyring.so` only captures the **login** password
- If your LUKS password ≠ login password, keyring won't unlock

**The Solution (Already Implemented in This Image):**

This image includes `pam_fde_boot_pw.so` which:
1. Retrieves the LUKS password from systemd
2. Injects it into gnome-keyring
3. Enables automatic unlock even when LUKS password ≠ login password

**Verification:**

Check that everything is installed and configured:

```bash
# Verify pam_fde_boot_pw is installed (check both locations)
ls -la /usr/lib/security/pam_fde_boot_pw.so
ls -la /usr/lib64/security/pam_fde_boot_pw.so  # On x86_64 systems

# Verify PAM configuration
grep "pam_fde_boot_pw" /etc/pam.d/greetd

# Check systemd in initrd (should see files)
ls /usr/lib/systemd/system/initrd*
```

**Note:** On x86_64 systems, the build creates a symlink from `/usr/lib/security/` to `/usr/lib64/security/` for cross-architecture PAM module compatibility. Both paths should work.

Fedora and bootc-based systems typically use systemd in initrd by default.

### Manual Installation (For Other Systems)

**Note**: This section is for reference only. This image already includes pam_fde_boot_pw.

If you need to install pam_fde_boot_pw on another system:

**Source**: https://git.sr.ht/~kennylevinsen/pam_fde_boot_pw

```bash
# Install build dependencies
dnf install -y meson ninja-build pam-devel systemd-devel keyutils-libs-devel

# Download and build
git clone https://git.sr.ht/~kennylevinsen/pam_fde_boot_pw
cd pam_fde_boot_pw
meson setup build
ninja -C build
sudo ninja -C build install
```

This installs the module to `/usr/lib/security/pam_fde_boot_pw.so`

**Update PAM configuration:**

Modify `/etc/pam.d/greetd` to add pam_fde_boot_pw BEFORE gnome-keyring:

```pam
#%PAM-1.0
# PAM configuration for greetd with LUKS FDE support

# Authentication
auth       include      system-login
auth       optional     pam_gnome_keyring.so

# Account validation
account    include      system-login

# Password management
password   optional     pam_gnome_keyring.so
password   include      system-login

# Session management
session    include      system-login
session    optional     /usr/lib/security/pam_fde_boot_pw.so inject_for=gkr
session    optional     pam_gnome_keyring.so auto_start
```

**CRITICAL:** `pam_fde_boot_pw.so` MUST come BEFORE `pam_gnome_keyring.so` in the session phase!

### Building pam_fde_boot_pw in a bootc Image

**Note**: This image already includes pam_fde_boot_pw via `build/25-pam-fde.sh`. This section is for reference.

The build script (`build/25-pam-fde.sh`) compiles and installs pam_fde_boot_pw during image build:

```bash
#!/usr/bin/bash

set -eoux pipefail

echo "::group:: Build and Install pam_fde_boot_pw"

# Install build dependencies
dnf5 install -y \
    git \
    meson \
    ninja-build \
    pam-devel \
    systemd-devel \
    keyutils-libs-devel

# Clone and build
cd /tmp
git clone https://git.sr.ht/~kennylevinsen/pam_fde_boot_pw
cd pam_fde_boot_pw
meson setup build
ninja -C build
ninja -C build install

# Clean up build artifacts
cd /
rm -rf /tmp/pam_fde_boot_pw

# Remove build-only dependencies (keep runtime deps)
dnf5 remove -y \
    git \
    meson \
    ninja-build \
    pam-devel \
    systemd-devel \
    keyutils-libs-devel

echo "::endgroup::"
```

The PAM configuration in `custom/system_files/etc/pam.d/greetd` includes the module.

### Alternative: Use Login Password for Keyring

If you don't want to implement `pam_fde_boot_pw.so`, you can:

1. **Set your login password to match your LUKS password**
   - This way `pam_gnome_keyring.so` captures the correct password
   
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
