# dank-niri

A template for building custom bootc operating system images based on the lessons from [Universal Blue](https://universal-blue.org/) and [Bluefin](https://projectbluefin.io). It is designed to be used manually, but is optimized to be bootstrapped by GitHub Copilot. After set up you'll have your own custom Linux. 

This template uses the **multi-stage build architecture** from , combining resources from multiple OCI containers for modularity and maintainability. See the [Architecture](#architecture) section below for details.

**Unlike previous templates, you are not modifying Bluefin and making changes.**: You are assembling your own Bluefin in the same exact way that Bluefin, Aurora, and Bluefin LTS are built. This is way more flexible and better for everyone since the image-agnostic and desktop things we love about Bluefin lives in @projectbluefin/common. 

 Instead, you create your own OS repository based on this template, allowing full customization while leveraging Bluefin's robust build system and shared components.

> Be the one who moves, not the one who is moved.

## What Makes dank-niri Different?

This custom bootc image is based on **Fedora Silverblue** and includes these default configurations:

### Added Packages (Build-time)
- **System packages**: bat, brightnessctl, dbus-tools, fd-find, fish, foot, fuzzel, git-delta, gnome-keyring-pam, helix, micro, nautilus, openfortivpn, podman-compose, podman-docker, power-profiles-daemon, qt5ct, qt6ct, ripgrep, xdg-desktop-portal-gtk, xdg-desktop-portal-gnome, xdg-terminal-exec, xdg-user-dirs, zoxide
- **From COPR**: starship (atim/starship), nushell (atim/nushell), yazi (lihaohong/yazi)
- **Microsoft apps**: Microsoft Edge (stable), VS Code Insiders - Installed from official Microsoft repositories

### Included Applications (Runtime)
- **CLI Tools (Homebrew)**: eza, vivid, numbat, ruff, topiary - Modern CLI utilities for enhanced productivity
- **Fonts (Homebrew)**: Nerd Fonts (Fira Code, JetBrains Mono, Meslo LG, Hack) - Programming fonts with icons and glyphs
- **GUI Apps (Flatpak)**: Firefox, Thunderbird, GNOME core apps, Pinta, Flatseal, Extension Manager, and more - Essential desktop applications

### System Configuration
- **Podman socket enabled** - Container runtime ready out of the box
- **Multi-stage build architecture** - Leverages @projectbluefin/common for desktop configuration
- **Homebrew integration** - Runtime package management via brew
- **Composefs enabled** - Efficient chunked updates for bootc with reduced bandwidth usage
- **Image rechunking enabled** - Optimized layer structure for 5-10x smaller updates

*This image serves as a starting point. Customize by modifying files in `build/`, `custom/brew/`, `custom/flatpaks/`, and `custom/ujust/` directories.*

*Last updated: 2026-02-01*

## About This Template

This repository was created from the [@projectbluefin/finpilot](https://github.com/projectbluefin/finpilot) template and configured as **dank-niri**.

### If You Want to Use This as a Template

You can fork or template this repository to create your own custom OS:

1. Click the green "Use this as a template" button and create a new repository
2. Select your owner, pick a repo name for your OS, and a description
3. In the "Jumpstart your project with Copilot (optional)" add this, modify to your liking:

```
Use @projectbluefin/finpilot as a template, name the OS the repository name. Ensure the entire operating system is bootstrapped. Ensure all github actions are enabled and running.  Ensure the README has the github setup instructions for cosign and the other steps required to finish the task.
```

## What's Included

### Build System
- Automated builds via GitHub Actions on every commit
- Awesome self hosted Renovate setup that keeps all your images and actions up to date.
- Automatic cleanup of old images (90+ days) to keep it tidy
- Pull request workflow - test changes before merging to main
  - PRs build and validate before merge
  - `main` branch builds `:stable` images
- Validates your files on pull requests so you never break a build:
  - Brewfile, Justfile, ShellCheck, Renovate config, and it'll even check to make sure the flatpak you add exists on FlatHub
- Production Grade Features
  - Container signing and SBOM Generation
  - See checklist below to enable these as they take some manual configuration

### Homebrew Integration
- Pre-configured Brewfiles for easy package installation and customization
- Includes curated collections: development tools, fonts, CLI utilities. Go nuts.
- Users install packages at runtime with `brew bundle`, aliased to premade `ujust commands`
- See [custom/brew/README.md](custom/brew/README.md) for details

### Flatpak Support
- Ship your favorite flatpaks
- Automatically installed on first boot after user setup
- See [custom/flatpaks/README.md](custom/flatpaks/README.md) for details

### ujust Commands
- User-friendly command shortcuts via `ujust`
- Pre-configured examples for app installation and system maintenance for you to customize
- See [custom/ujust/README.md](custom/ujust/README.md) for details

### Build Scripts
- Modular numbered scripts (10-, 20-, 30-) run in order
- Example scripts included for third-party repositories and desktop replacement
- Helper functions for safe COPR usage
- See [build/README.md](build/README.md) for details

## Quick Start

**Note**: This repository has already been configured as **dank-niri**. If you're using this as-is, skip to step 3 below. If you want to create your own custom OS based on this, see the "About This Template" section above.

### 1. ~~Create Your Repository~~ ✅ Done

~~Click "Use this template" to create a new repository from this template.~~

This repository is already set up as **dank-niri**.

### 2. ~~Rename the Project~~ ✅ Done

~~Important: Change `finpilot` to your repository name in these 6 files~~

All project files have been renamed from `finpilot` to **dank-niri**:

1. ✅ `Containerfile` (line 4): `# Name: dank-niri`
2. ✅ `Justfile` (line 1): `export image_name := env("IMAGE_NAME", "dank-niri")`
3. ✅ `README.md` (line 1): `# dank-niri`
4. ✅ `artifacthub-repo.yml` (line 5): `repositoryID: dank-niri`
5. ✅ `custom/ujust/README.md` (~line 175): `localhost/dank-niri:stable`
6. ✅ `.github/workflows/clean.yml` (line 23): `packages: dank-niri`

### 3. Enable GitHub Actions

- Go to the "Actions" tab in your repository
- Click "I understand my workflows, go ahead and enable them"

Your first build will start automatically! 

Note: Image signing is disabled by default. Your images will build successfully without any signing keys. Once you're ready for production, see "Optional: Enable Image Signing" below.

### 4. Customize Your Image

Choose your base image in `Containerfile` (line 23):
```dockerfile
FROM ghcr.io/ublue-os/bluefin:stable
```

Add your packages in `build/10-build.sh`:
```bash
dnf5 install -y package-name
```

Customize your apps:
- Add Brewfiles in `custom/brew/` ([guide](custom/brew/README.md))
- Add Flatpaks in `custom/flatpaks/` ([guide](custom/flatpaks/README.md))
- Add ujust commands in `custom/ujust/` ([guide](custom/ujust/README.md))

### 5. Development Workflow

All changes should be made via pull requests:

1. Open a pull request on GitHub with the change you want.
3. The PR will automatically trigger:
   - Build validation
   - Brewfile, Flatpak, Justfile, and shellcheck validation
   - Test image build
4. Once checks pass, merge the PR
5. Merging triggers publishes a `:stable` image

### 6. Deploy Your Image

Switch to your image:
```bash
sudo bootc switch ghcr.io/your-username/your-repo-name:stable
sudo systemctl reboot
```

## Optional: Enable Image Signing

Image signing is disabled by default to let you start building immediately. However, signing is strongly recommended for production use.

### Why Sign Images?

- Verify image authenticity and integrity
- Prevent tampering and supply chain attacks
- Required for some enterprise/security-focused deployments
- Industry best practice for production images

### Setup Instructions

1. Generate signing keys:
```bash
cosign generate-key-pair
```

This creates two files:
- `cosign.key` (private key) - Keep this secret
- `cosign.pub` (public key) - Commit this to your repository

2. Add the private key to GitHub Secrets:
   - Copy the entire contents of `cosign.key`
   - Go to your repository on GitHub
   - Navigate to Settings → Secrets and variables → Actions ([GitHub docs](https://docs.github.com/en/actions/security-guides/encrypted-secrets#creating-encrypted-secrets-for-a-repository))
   - Click "New repository secret"
   - Name: `SIGNING_SECRET`
   - Value: Paste the entire contents of `cosign.key`
   - Click "Add secret"

3. Replace the contents of `cosign.pub` with your public key:
   - Open `cosign.pub` in your repository
   - Replace the placeholder with your actual public key
   - Commit and push the change

4. Enable signing in the workflow:
   - Edit `.github/workflows/build.yml`
   - Find the "OPTIONAL: Image Signing with Cosign" section.
   - Uncomment the steps to install Cosign and sign the image (remove the `#` from the beginning of each line in that section).
   - Commit and push the change

5. Your next build will produce signed images!

Important: Never commit `cosign.key` to the repository. It's already in `.gitignore`.

## Love Your Image? Let's Go to Production

Ready to take your custom OS to production? Enable these features for enhanced security, reliability, and performance:

### Production Checklist

- [ ] **Enable Image Signing** (Recommended)
  - Provides cryptographic verification of your images
  - Prevents tampering and ensures authenticity
  - See "Optional: Enable Image Signing" section above for setup instructions
  - Status: **Disabled by default** to allow immediate testing

- [ ] **Enable SBOM Attestation** (Recommended)
  - Generates Software Bill of Materials for supply chain security
  - Provides transparency about what's in your image
  - Requires image signing to be enabled first
  - To enable:
    1. First complete image signing setup above
    2. Edit `.github/workflows/build.yml`
    3. Find the "OPTIONAL: SBOM Attestation" section around line 232
    4. Uncomment the "Add SBOM Attestation" step
    5. Commit and push
  - Status: **Disabled by default** (requires signing first)

- [x] **Image Rechunking** (Enabled)
  - Optimizes bootc image layers for better update performance
  - Reduces update sizes by 5-10x through evenly-sized, resumable layer chunks
  - Improves download resumability with evenly sized layers
  - Configured with `--max-layers 67` for optimal balance
  - Status: **Enabled** - Runs automatically on every build
  - See [docs/CHUNKING_COMPARISON.md](docs/CHUNKING_COMPARISON.md) for implementation details

#### How Image Rechunking Works

Image rechunking is now **enabled by default** in this repository. The workflow automatically:

1. Builds the container image
2. Rechunks the image layers for optimal update performance
3. Pushes the optimized image to the registry

The rechunking step is implemented in `.github/workflows/build.yml`:

```yaml
- name: Rechunk image
  run: |
    # Get the image ID to reference it directly
    IMAGE_ID=$(podman images --filter "reference=localhost/${{ env.IMAGE_NAME }}:${{ env.DEFAULT_TAG }}" --format "{{.ID}}")
    sudo podman run --rm --privileged \
      -v /var/lib/containers:/var/lib/containers \
      --entrypoint /usr/libexec/bootc-base-imagectl \
      "$IMAGE_ID" \
      rechunk --max-layers 67 \
      "localhost/${{ env.IMAGE_NAME }}:${{ env.DEFAULT_TAG }}" \
      "localhost/${{ env.IMAGE_NAME }}:${{ env.DEFAULT_TAG }}"
```

**Configuration:**
- Uses `--max-layers 67` for optimal balance between granularity and overhead
- Rechunks in-place (same input and output reference)
- Runs automatically on every build before pushing to registry

**Alternative configurations:**

If you want to adjust the number of layers, you can modify the `--max-layers` parameter:
- `--max-layers 67`: Recommended default (optimal balance)
- `--max-layers 96`: Higher granularity (more layers, slightly larger overhead)
- `--max-layers 48`: Lower granularity (fewer layers, faster processing)

**References:**
- [docs/CHUNKING_COMPARISON.md](docs/CHUNKING_COMPARISON.md) - Comparison with Red Hat article approach
- [CoreOS rpm-ostree build-chunked-oci documentation](https://coreos.github.io/rpm-ostree/build-chunked-oci/)
- [bootc documentation](https://containers.github.io/bootc/)

### After Enabling Production Features

Your workflow will:
- Rechunk images for optimized updates (already enabled)
- Sign all images with your key (optional)
- Generate and attach SBOMs (optional)
- Provide full supply chain transparency (optional)

Users can verify your images with:
```bash
cosign verify --key cosign.pub ghcr.io/your-username/your-repo-name:stable
```

## Detailed Guides

- [Homebrew/Brewfiles](custom/brew/README.md) - Runtime package management
- [Flatpak Preinstall](custom/flatpaks/README.md) - GUI application setup
- [ujust Commands](custom/ujust/README.md) - User convenience commands
- [Build Scripts](build/README.md) - Build-time customization
- [Bootc Chunking Implementation](docs/REDHAT_ARTICLE_COMPARISON.md) - How our chunking compares to Red Hat article
- [Composefs Documentation](docs/COMPOSEFS.md) - Client-side chunked updates

## Architecture

This template follows the **multi-stage build architecture** from @projectbluefin/distroless, as documented in the [Bluefin Contributing Guide](https://docs.projectbluefin.io/contributing/).

### Multi-Stage Build Pattern

**Stage 1: Context (ctx)** - Combines resources from multiple sources:
- Local build scripts (`/build`)
- Local custom files (`/custom`)
- **@projectbluefin/common** - Desktop configuration shared with Aurora
- **@projectbluefin/branding** - Branding assets
- **@ublue-os/artwork** - Artwork shared with Aurora and Bazzite
- **@ublue-os/brew** - Homebrew integration

**Stage 2: Base Image** - Default options:
- `ghcr.io/ublue-os/silverblue-main:latest` (Fedora-based, default)
- `quay.io/centos-bootc/centos-bootc:stream10` (CentOS-based alternative)

### Benefits of This Architecture

- **Modularity**: Compose your image from reusable OCI containers
- **Maintainability**: Update shared components independently
- **Reproducibility**: Renovate automatically updates OCI tags to SHA digests
- **Consistency**: Share components across Bluefin, Aurora, and custom images

### OCI Container Resources

The template imports files from these OCI containers at build time:

```dockerfile
COPY --from=ghcr.io/ublue-os/base-main:latest /system_files /oci/base
COPY --from=ghcr.io/projectbluefin/common:latest /system_files /oci/common
COPY --from=ghcr.io/ublue-os/brew:latest /system_files /oci/brew
```

Your build scripts can access these files at:
- `/ctx/oci/base/` - Base system configuration
- `/ctx/oci/common/` - Shared desktop configuration
- `/ctx/oci/branding/` - Branding assets
- `/ctx/oci/artwork/` - Artwork files
- `/ctx/oci/brew/` - Homebrew integration files

**Note**: Renovate automatically updates `:latest` tags to SHA digests for reproducible builds.

## Local Testing

Test your changes before pushing:

```bash
just build              # Build container image
just build-qcow2        # Build VM disk image
just run-vm-qcow2       # Test in browser-based VM
```

## Community

- [Universal Blue Discord](https://discord.gg/WEu6BdFEtp)
- [bootc Discussion](https://github.com/bootc-dev/bootc/discussions)

## Learn More

- [Universal Blue Documentation](https://universal-blue.org/)
- [bootc Documentation](https://containers.github.io/bootc/)
- [Video Tutorial by TesterTech](https://www.youtube.com/watch?v=IxBl11Zmq5wE)

## Security

This template provides security features for production use:
- Optional SBOM generation (Software Bill of Materials) for supply chain transparency
- Optional image signing with cosign for cryptographic verification
- Automated security updates via Renovate
- Build provenance tracking

These security features are disabled by default to allow immediate testing. When you're ready for production, see the "Love Your Image? Let's Go to Production" section above to enable them.
