# Debian Metadata Templates

This directory stores reusable Debian packaging templates for the Trojan Pro Client.

## Files

- `control.in` — Debian control-file template
- `trojan-pro-client.desktop.in` — desktop entry template

## Variable source

The templates are rendered from values in:

- `../release-metadata.env`

## Important naming rule

Do **not** assume the Debian package name and Linux executable name are the same string.

For this project:
- Debian package name: `trojan-pro-client`
- Linux executable name: `trojan_pro_client`

That split exists because:
- Debian packages want kebab-case
- Dart / Flutter binaries commonly end up snake_case

If you point `Exec=` at `trojan-pro-client`, the launcher will look neat and fail beautifully.

## Expected install surface

- bundle copied into `/opt/trojan-pro-client/`
- launcher installed to `/usr/share/applications/trojan-pro-client.desktop`
- optional icon installed to `/usr/share/icons/hicolor/256x256/apps/trojan-pro-client.png`
