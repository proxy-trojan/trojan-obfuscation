# Linux Packaging

This directory is reserved for Linux-first packaging work for the Trojan-Pro client.

## Structure

- `assets/` — optional packaging assets such as icons
- `artifacts/` — built package outputs grouped by release label
- `deb/` — reusable Debian metadata templates
- `staging/` — generated Debian assembly directories (ephemeral)
- `release-metadata.env` — naming/version/install-path draft values consumed by the packaging script
- future: `appimage/` — optional AppImage flow

## Primary scripts

```bash
scripts/build-client-linux-package.sh
scripts/build-client-linux-bundle-tar.sh
```

## Current naming rule

Do not collapse all surfaces into one string.

- display name: `Trojan Pro Client`
- Debian package name: `trojan-pro-client`
- Linux executable name: `trojan_pro_client`

If these drift, the package may build and the launcher may still fail.

## Important

This script assumes:
- Flutter SDK is installed
- Linux desktop support is enabled
- `client/linux/` scaffolding exists
- `dpkg-deb` is available
- `python3` is available for template rendering
- the built Flutter Linux bundle contains `trojan_pro_client`

If those prerequisites are not met, packaging will fail by design.
