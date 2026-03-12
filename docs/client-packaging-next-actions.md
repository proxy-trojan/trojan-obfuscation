# Client Packaging — Next Actions

## Objective

Get from the current Linux-first packaging baseline to a **repeatable cross-platform client packaging workflow** with the least wasted motion.

## Recommended execution order

### 1. Keep the Flutter toolchain healthy
- keep Flutter SDK available for CI and local validation
- prefer non-root build lanes for repeatability
- keep `flutter doctor` green on build runners

### 2. Validate the app before packaging
```bash
cd client
flutter pub get
flutter analyze
flutter run -d linux
```

### 3. Validate the runtime flow
- run the real adapter path
- confirm profile/password/connect/disconnect
- confirm diagnostics export

### 4. Build Linux artifacts
```bash
cd client
flutter build linux --release
```

Then:
```bash
scripts/build-client-linux-package.sh
scripts/build-client-linux-bundle-tar.sh
```

### 5. Keep Linux smoke validation real
- install the `.deb`
- launch from app menu and terminal on a GUI-capable machine
- repeat the core client flow

### 6. Move Windows / macOS packaging to CI runners
- Windows runner: `flutter build windows --release` + `scripts/package-client-windows-zip.sh`
- macOS runner: `flutter build macos` + `scripts/package-client-macos-app-zip.sh`

### 7. Optionally enable Android lane
- provision Android SDK
- run `flutter build apk --release`
- collect artifact with `scripts/collect-client-android-apk.sh`

## Rule

Do not jump directly to packaging before steps 1-4 are green.
A broken package is worse than no package.
