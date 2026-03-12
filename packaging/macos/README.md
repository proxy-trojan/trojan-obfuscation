# macOS Packaging

This directory stores macOS client packaging outputs.

## First milestone

- build on a macOS runner
- package the generated `.app` bundle as a `.zip`

## Artifact convention

```text
packaging/macos/artifacts/v<version-label>/
  trojan-pro-client_<version-label>_macos-app.zip
```

## Notes

This is intentionally **not** notarized DMG / PKG yet.
The first goal is a usable internal handoff artifact.
