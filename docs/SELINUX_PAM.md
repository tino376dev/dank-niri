# SELinux and PAM Configuration for Fedora

## Question: Does Fedora with SELinux Impact Our PAM Configuration?

**Short Answer**: No, our configuration is correct. The `include system-login` directive properly handles SELinux context setup.

## How It Works

### PAM Include Directive

When we use `include system-auth` in our greetd PAM configuration, we inherit **all** modules from Fedora's `/usr/lib/pam.d/system-auth` file, including SELinux-related modules.

**CRITICAL**: greetd uses `system-auth`, not `system-login`:
- **system-auth** = For authentication services (display managers, sshd, sudo)
- **system-login** = For local console logins (getty, login command)

### Typical Fedora system-auth Structure

Fedora's `/usr/lib/pam.d/system-auth` includes critical SELinux modules:

```pam
auth       required   pam_env.so
auth       required   pam_faildelay.so
auth       sufficient pam_fprintd.so
auth       sufficient pam_unix.so try_first_pass nullok
auth       required   pam_deny.so

account    required   pam_unix.so
account    sufficient pam_localuser.so
account    sufficient pam_succeed_if.so uid < 1000 quiet
account    required   pam_permit.so

password   requisite  pam_pwquality.so try_first_pass local_users_only retry=3
password   sufficient pam_unix.so try_first_pass use_authtok nullok sha512 shadow
password   required   pam_deny.so

session    optional   pam_keyinit.so revoke
session    required   pam_limits.so
session    [success=1 default=ignore] pam_succeed_if.so service in crond quiet use_uid
session    required   pam_unix.so
session    optional   pam_systemd.so
```

Note: SELinux modules (`pam_selinux.so close/open`) are typically in the service-specific PAM file (like greetd), not in `system-auth` itself.

### Our greetd PAM Configuration

```pam
#%PAM-1.0
# PAM configuration for greetd on Fedora
# Uses system-auth (for display managers) not system-login (for console)

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

### Execution Order (Session Phase)

When a user logs in, PAM executes session modules in this order:

1. **`session required pam_selinux.so close`** - Prepare SELinux context transition
2. **`session required pam_loginuid.so`** - Set audit login UID
3. **`session optional pam_keyinit.so force revoke`** - Initialize kernel keyring
4. **`session include system-auth`** runs, which executes:
   - `pam_keyinit.so revoke` - Manage kernel keyring
   - `pam_limits.so` - Set resource limits
   - `pam_unix.so` - Unix session setup
   - `pam_systemd.so` - Register with systemd
5. **`session required pam_selinux.so open`** - Set SELinux context for new session
   
2. **`session optional pam_gnome_keyring.so auto_start`** runs:
   - Starts gnome-keyring-daemon
   - Unlocks the keyring with the password
   - **Runs with correct SELinux context** (already set by step 5)
   
3. **`session include postlogin`** runs:
   - Post-session setup tasks

## Why This Is Correct

1. **SELinux context is set BEFORE our custom modules run**
   - `pam_selinux.so open` runs AFTER `system-auth` setup
   - Our modules (`pam_gnome_keyring`) run AFTER SELinux context is set
   - They inherit the correct SELinux context

2. **Our modules are `optional`**
   - If they fail, login still succeeds
   - If SELinux setup fails, login fails immediately (pam_selinux.so is `required`)
   - This prevents insecure sessions

3. **SELinux modules are explicitly placed**
   - `pam_selinux.so close` runs early to prepare context transition
   - `pam_selinux.so open` runs late to set final context
   - This is the standard Fedora pattern for display managers

## SELinux Context Restoration

During the build process, we explicitly restore SELinux contexts:

```bash
# In build/25-pam-fde.sh
restorecon -v /usr/lib*/security/pam_fde_boot_pw.so
```

This ensures `pam_fde_boot_pw.so` has the correct SELinux label (`lib_t` or `textrel_shlib_t`) so that:
- PAM can load the module
- The module can access systemd's keyring
- The module can inject passwords into gnome-keyring

## Common Concerns Addressed

### "Should we add pam_selinux.so explicitly?"

**No**. Adding it explicitly could cause issues:
- It might run twice (once from `system-login`, once from our config)
- The order relative to `system-login`'s other modules might be wrong
- Fedora updates to `system-login` wouldn't be applied

### "What if system-login doesn't include pam_selinux.so?"

This would be a bug in Fedora's base configuration. However:
- Fedora Silverblue ships with pam_selinux.so in system-login
- This is a core requirement for SELinux-enabled systems
- If it's missing, many system services would fail, not just greetd

### "Does our custom module need special SELinux configuration?"

Not beyond basic file contexts. The `restorecon` command ensures:
- The .so file has the correct type (lib_t)
- PAM can load it
- It runs in the same SELinux domain as PAM

If additional SELinux policy is needed, it would be for:
- Accessing systemd's keyring (systemd should handle this)
- Interacting with gnome-keyring (gnome-keyring should handle this)

## Verification

To verify SELinux is working correctly after deployment:

```bash
# 1. Check SELinux is enabled
getenforce
# Should show: Enforcing

# 2. Check PAM module has correct context
ls -Z /usr/lib*/security/pam_fde_boot_pw.so
# Should show something like: system_u:object_r:lib_t:s0

# 3. Check for SELinux denials related to PAM
sudo ausearch -m AVC -ts recent | grep pam
# Should show no denials (or only denials for unrelated things)

# 4. Check that greetd PAM config is used
cat /usr/lib/pam.d/greetd
# Should show our custom config with pam_fde_boot_pw.so

# 5. Verify login works without prompts
# Log out and log back in - no keyring prompt should appear
```

## Troubleshooting SELinux Issues

If you encounter SELinux denials:

```bash
# 1. Check for recent denials
sudo ausearch -m AVC -ts today

# 2. Check if PAM module is being blocked
sudo ausearch -m AVC -ts today | grep pam_fde_boot_pw

# 3. If denials exist, generate policy module
sudo ausearch -m AVC -ts today | audit2allow -M mypol

# 4. Review the policy before installing
cat mypol.te

# 5. If it looks safe, install it
sudo semodule -i mypol.pp
```

**Note**: In most cases, no additional SELinux policy should be needed. If denials occur, it's likely a bug in either:
- The pam_fde_boot_pw module
- Systemd's credential storage
- GNOME Keyring's SELinux policy

## References

- [PAM Configuration Syntax](https://linux.die.net/man/5/pam.conf)
- [pam_selinux(8) Manual](https://linux.die.net/man/8/pam_selinux)
- [Fedora SELinux Documentation](https://docs.fedoraproject.org/en-US/quick-docs/selinux-getting-started/)
- [SELinux and PAM](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/using_selinux/managing-confined-and-unconfined-users_using-selinux#setting-the-selinux-context-for-a-pam-module_managing-confined-and-unconfined-users)

## Conclusion

**Our PAM configuration is correct for Fedora with SELinux.**

- SELinux context setup is handled by `include system-login`
- Our custom modules run with the correct context
- SELinux file labels are set during build
- No additional SELinux policy is typically needed

The use of `include system-login` is the **recommended approach** because:
1. It inherits all Fedora defaults (including SELinux modules)
2. It receives updates when Fedora updates system-login
3. It maintains the correct module ordering
4. It's the same approach used by other display managers (GDM, SDDM)
