# Linux Packaging Assets

Put Linux packaging assets here when they become available.

## Planned files

- `trojan-pro-client.png` — primary desktop icon copied into the Debian package when present

## Current rule

The packaging script should treat the icon as optional until a real app icon exists.
That means a missing icon should not block the first internal packaging pass.
