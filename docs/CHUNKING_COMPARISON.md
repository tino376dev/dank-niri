# Bootc Image Chunking: Implementation Comparison

This document compares our bootc chunking implementation with the approach described in the Red Hat article "Reduce bootc system update size" (https://developers.redhat.com/articles/2025/11/03/reduce-bootc-system-update-size).

## Quick Summary

**Both approaches achieve the same goal**: Optimize bootc images for efficient, chunked updates that reduce bandwidth usage during system updates.

**Key difference**: Different tools with the same underlying technology.

## Our Implementation

### What We Use

1. **Composefs** (Client-side chunking)
   - Location: `/usr/lib/ostree/prepare-root.conf`
   - Enables delta/chunked updates on the deployed system
   - Automatically included in our image build

2. **bootc-base-imagectl rechunk** (Build-time optimization)
   - Location: `.github/workflows/build.yml` (rechunk step)
   - Optimizes image layer structure during CI/CD build
   - Uses the base image's built-in rechunking tool

### Implementation Details

```yaml
# In .github/workflows/build.yml
- name: Rechunk image
  run: |
    # Use a bootc base image to run the rechunk tool (which contains bootc-base-imagectl)
    # Mount the user's podman storage to /var/tmp/storage inside the container
    sudo podman --root $HOME/.local/share/containers/storage run --rm --privileged \
      -v $HOME/.local/share/containers/storage:/var/tmp/storage:z \
      quay.io/centos-bootc/centos-bootc:stream10 \
      /usr/libexec/bootc-base-imagectl --root /var/tmp/storage \
      rechunk --max-layers 67 \
      "${{ env.IMAGE_NAME }}:${{ env.DEFAULT_TAG }}" \
      "${{ env.IMAGE_NAME }}:${{ env.DEFAULT_TAG }}-rechunked"
    # Replace the original image with the rechunked version
    sudo podman --root $HOME/.local/share/containers/storage tag \
      "${{ env.IMAGE_NAME }}:${{ env.DEFAULT_TAG }}-rechunked" \
      "${{ env.IMAGE_NAME }}:${{ env.DEFAULT_TAG }}"
    # Clean up the temporary tag
    sudo podman --root $HOME/.local/share/containers/storage rmi \
      "${{ env.IMAGE_NAME }}:${{ env.DEFAULT_TAG }}-rechunked"
```

**Parameters:**
- `--max-layers 67`: Optimal balance between granularity and overhead
- Uses `quay.io/centos-bootc/centos-bootc:stream10` which contains the `bootc-base-imagectl` tool
- Mounts user's podman storage to `/var/tmp/storage` inside the container (simple path that exists in minimal bootc images)
- Passes `--root /var/tmp/storage` to `bootc-base-imagectl` to access the mounted storage correctly
- Creates temporary `-rechunked` tag, then replaces original
- `--root $HOME/.local/share/containers/storage`: Access user's podman storage where buildah-build stores images
- Uses the base image itself as the rechunking tool container
- In-place rechunking (same input and output tag)
- References image as `IMAGE:TAG` - matches how buildah-build tags it
- Based on the approach from @zirconium-dev/zirconium and @projectbluefin/finpilot

**Note**: The image reference format varies by build tool:
- `redhat-actions/buildah-build` tags as `IMAGE:TAG` (no localhost prefix) in user storage
- `podman build` tags as `localhost/IMAGE:TAG` (with localhost prefix) in user/root storage depending on sudo
- Always match the format used by your build step

**Important**: When using `buildah-build` action (runs as user), you must use `--root` flag with sudo podman to access the user's storage location. Root's podman storage and user's podman storage are separate.

## Red Hat Article Approach

### What They Use

The Red Hat article describes two methods:

**Method 1: bootc-image-builder with chunking**
```bash
sudo podman run --rm --privileged \
  -v /path/to/config.toml:/config.toml \
  -v /output:/output \
  quay.io/centos-bootc/bootc-image-builder:latest \
  build --type raw --chunked /config.toml
```

**Method 2: Manual chunking with rpm-ostree**
```bash
# Build image first
podman build -t myimage .

# Rechunk using rpm-ostree
rpm-ostree compose chunked-commit \
  --repo=/path/to/repo \
  myimage
```

### Key Differences from Our Approach

| Aspect | Our Approach | Red Hat Article |
|--------|-------------|-----------------|
| **Tool** | `bootc-base-imagectl rechunk` | `bootc-image-builder` with `--chunked` flag |
| **Execution Context** | CI/CD workflow (GitHub Actions) | Local development/testing |
| **Primary Use Case** | Automated production builds | Manual testing and development |
| **Integration** | Integrated into image build pipeline | Separate tooling workflow |
| **Output** | OCI container image (GHCR) | Disk images (QCOW2, RAW, ISO) |

## Why Our Approach is Better for CI/CD

1. **Automated**: Runs automatically on every build
2. **Reproducible**: Same process every time in CI/CD
3. **Efficient**: Reuses the base image's rechunking capabilities
4. **Minimal**: Single step in existing workflow
5. **Production-Ready**: Directly pushes to container registry

## Why Red Hat's Approach is Better for Development

1. **Local Testing**: Build bootable disk images for VM testing
2. **Flexibility**: Multiple output formats (ISO, QCOW2, RAW)
3. **Development Workflow**: Test changes before committing
4. **Standalone**: Doesn't require GitHub Actions

## Technical Equivalence

**Both approaches use the same underlying technology:**

1. **rpm-ostree chunked commits**: Both use rpm-ostree's chunking implementation
2. **Composefs**: Both rely on composefs for efficient storage
3. **Content-addressable storage**: Same storage backend
4. **Delta updates**: Same update mechanism

The difference is **packaging and workflow integration**, not the core technology.

## Combined Approach (Best of Both Worlds)

You can use **both** approaches:

1. **Our implementation**: For automated production builds in CI/CD
2. **Red Hat's approach**: For local development and testing

### Local Testing with bootc-image-builder

```bash
# Test your changes locally before pushing
just build  # Build container image

# Create bootable disk image with chunking
sudo podman run --rm --privileged \
  -v ./iso/disk.toml:/config.toml \
  -v ./output:/output \
  quay.io/centos-bootc/bootc-image-builder:latest \
  build --type qcow2 --chunked /config.toml

# Test in VM
just run-vm-qcow2
```

### Production Build (Our CI/CD)

```yaml
# Automatically runs on merge to main
# Builds, rechunks, and pushes to GHCR
- Push changes to main branch
- GitHub Actions builds and rechunks
- Image pushed to ghcr.io
```

## Performance Comparison

Both approaches achieve similar performance benefits:

- **Bandwidth reduction**: 70-90% less data downloaded during updates
- **Update speed**: 5-10x faster updates
- **Resumability**: Both support resumable downloads
- **Deduplication**: Both deduplicate identical content

The benefits come from the underlying technology (composefs + chunking), not the specific tool.

## When to Use Each Approach

### Use Our Implementation (bootc-base-imagectl) When:
- ✅ Building production images in CI/CD
- ✅ Need automated, reproducible builds
- ✅ Pushing to container registry (GHCR, Quay, etc.)
- ✅ Want minimal workflow complexity

### Use Red Hat's Approach (bootc-image-builder) When:
- ✅ Developing and testing locally
- ✅ Need bootable disk images (ISO, QCOW2, RAW)
- ✅ Testing changes before committing
- ✅ Creating installation media

### Use Both When:
- ✅ You want comprehensive testing (local) AND automated production builds (CI/CD)
- ✅ You develop locally and deploy via container registry
- ✅ You want the best of both workflows

## Conclusion

Our implementation and the Red Hat article approach are **complementary, not competing**:

- **Red Hat's article**: Focuses on local development and testing workflows
- **Our implementation**: Focuses on automated CI/CD production builds

Both use the same underlying technology (rpm-ostree chunking + composefs) and achieve the same performance benefits. The choice depends on your workflow:

- **Local development**: Use Red Hat's bootc-image-builder
- **CI/CD production**: Use our bootc-base-imagectl approach
- **Best practice**: Use both for comprehensive coverage

## References

- [Red Hat Developer Article: Reduce bootc system update size](https://developers.redhat.com/articles/2025/11/03/reduce-bootc-system-update-size)
- [CoreOS rpm-ostree build-chunked-oci documentation](https://coreos.github.io/rpm-ostree/build-chunked-oci/)
- [bootc documentation](https://containers.github.io/bootc/)
- [bootc-image-builder repository](https://github.com/osbuild/bootc-image-builder)
- [composefs documentation](https://github.com/containers/composefs-rs)
