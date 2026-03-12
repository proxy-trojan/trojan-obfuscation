# Trojan-Pro Client

Desktop-first client workspace for Trojan-Pro.

## Scope

Current client targets:
- Linux
- Windows
- macOS
- Android (release pipeline supported)

## Local development

```bash
cd client
flutter pub get
flutter analyze
flutter run -d linux
```

## Build

### Linux

```bash
flutter build linux --release
```

### Windows

```bash
flutter build windows --release
```

### macOS

```bash
flutter build macos
```

### Android

```bash
flutter build apk --release
```

## Release outputs

GitHub Actions release flow currently produces:
- Linux `.deb`
- Linux `.tar.gz`
- Windows `.zip`
- macOS `.app.zip`
- Android `.apk`

## Related docs

- `../docs/client-product-architecture.md`
- `../docs/client-packaging-readiness.md`
- `../docs/client-cross-platform-packaging.md`
- `../docs/branching-and-release-status.md`
