# Composefs and Chunked Updates

## What is Composefs?

Composefs is an efficient storage backend for bootc/ostree systems that enables chunked/delta updates. When enabled, it significantly reduces bandwidth usage during system updates by only downloading changed portions of the system image instead of entire layers.

## How It Works

Traditional container updates download entire layers even when only small portions have changed. With composefs enabled:

1. **Content-addressable storage**: Files are stored by their content hash
2. **Delta updates**: Only changed blocks are downloaded during updates
3. **Deduplication**: Identical files across updates share storage
4. **Reduced bandwidth**: Updates typically use 70-90% less bandwidth

## Configuration

This image has composefs enabled via `/usr/lib/ostree/prepare-root.conf`:

```ini
[composefs]
enabled = true
```

This configuration file is automatically included in the image during the build process from `custom/system_files/usr/lib/ostree/prepare-root.conf`.

## Benefits

- **Faster updates**: Less data to download means quicker update times
- **Lower bandwidth costs**: Particularly beneficial on metered connections
- **Storage efficiency**: Deduplication reduces disk space usage
- **Better reliability**: Smaller updates are less likely to fail or be interrupted

## Technical Details

For more information about composefs:
- [bootc composefs documentation](https://bootc-dev.github.io/bootc/experimental-composefs.html)
- [ostree-prepare-root man page](https://ostreedev.github.io/ostree/man/ostree-prepare-root.html)
- [composefs GitHub repository](https://github.com/containers/composefs-rs)

## Verification

To verify composefs is enabled after deployment:

```bash
cat /usr/lib/ostree/prepare-root.conf
```

You should see:
```ini
[composefs]
enabled = true
```

## Status

Composefs support is recommended for bootc images and is considered stable for production use as of bootc 1.1.0+.
