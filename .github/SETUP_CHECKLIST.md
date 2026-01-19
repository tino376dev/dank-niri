# Repository Setup Checklist

## ✅ Completed Setup

### 1. ✅ Template Renamed
- ✅ Updated `finpilot` to `dank-niri` in: Containerfile, Justfile, README.md, artifacthub-repo.yml, workflows, custom files

### 2. GitHub Actions (Ready to Enable)
- [ ] Settings → Actions → General → Enable workflows
- [ ] Set "Read and write permissions" (if needed)

Once enabled, the first build will start automatically and create: `ghcr.io/tino376dev/dank-niri:stable`

### 3. Deploy Your OS
After the first build completes:
```bash
sudo bootc switch --transport registry ghcr.io/tino376dev/dank-niri:stable
sudo systemctl reboot
```

## Optional: Production Features

### Enable Signing (Recommended)
```bash
cosign generate-key-pair
# Add cosign.key to GitHub Secrets as SIGNING_SECRET
# Uncomment signing steps in .github/workflows/build.yml
```

See README.md for detailed signing instructions.

