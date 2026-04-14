# Client Cross-Platform Packaging Matrix

## Latest validated CI status / 最新已验证 CI 状态

**EN**
- As of 2026-04-14, the client packaging pipeline is defined to build:
  - Linux `.deb` + `.tar.gz`
  - Windows `.zip`
  - macOS `.app.zip`
  - optional Android `.apk`
- The desktop lanes now also run two executable gates before artifact upload:
  - release-truth validation (`scripts/validate_client_release_truth.py`)
  - packaged smoke (`scripts/client_packaged_smoke.py`)

**中文**
- 截至 2026-04-14，client packaging 流水线已定义产出：
  - Linux `.deb` + `.tar.gz`
  - Windows `.zip`
  - macOS `.app.zip`
  - 可选 Android `.apk`
- 桌面三端在上传制品前还会执行两道可执行 gate：
  - release truth 校验（`scripts/validate_client_release_truth.py`）
  - packaged smoke（`scripts/client_packaged_smoke.py`）

## Current objective

Turn the client packaging story from a Linux-first local script into a repeatable CI matrix with per-platform artifact expectations.

## Verified local reality

### Linux host

Verified on the current Linux machine:
- `flutter analyze` passes
- `flutter build linux --release` passes
- Debian package build passes
- `.deb` install / uninstall smoke test passes
- bundle tarball packaging passes

### Windows on Linux host

Not supported from the current Linux host.
Actual Flutter result:
- `flutter build windows --release` → `"build windows" only supported on Windows hosts.`

### macOS on Linux host

Not supported from the current Linux host.
Actual Flutter result on Linux host:
- `flutter build macos` subcommand not available

### Android on Linux host

Potentially supported, but requires Android SDK.
Actual current result:
- `flutter build apk --release` → `No Android SDK found`

## Packaging matrix

| Platform | Runner | Build command | Artifact target | Current posture |
|---|---|---|---|---|
| Linux | Ubuntu | `flutter build linux --release` | `.deb` + `.tar.gz` bundle | ready now |
| Windows | Windows runner | `flutter build windows --release` | `.zip` of release directory | CI only |
| macOS | macOS runner | `flutter build macos` | `.app.zip` | CI only |
| Android | Ubuntu + Android SDK | `flutter build apk --release` | `.apk` | optional lane |

## Artifact naming convention

All platform outputs should land under a version label directory:

```text
packaging/<platform>/artifacts/v<version-label>/
```

Examples:

```text
packaging/linux/artifacts/v0.1.0-internal-alpha.1/
  trojan-pro-client_0.1.0~internal.alpha.1-1_amd64.deb
  trojan-pro-client_0.1.0-internal-alpha.1_linux-x64-bundle.tar.gz

packaging/windows/artifacts/v0.1.0-internal-alpha.1/
  trojan-pro-client_0.1.0-internal-alpha.1_windows-x64.zip

packaging/macos/artifacts/v0.1.0-internal-alpha.1/
  trojan-pro-client_0.1.0-internal-alpha.1_macos-app.zip

packaging/android/artifacts/v0.1.0-internal-alpha.1/
  trojan-pro-client_0.1.0-internal-alpha.1_android-release.apk
```

## CI workflow

Workflow file:
- `.github/workflows/client-packaging.yml`

Jobs:
1. Linux `.deb` + `.tar.gz`
2. Windows `.zip`
3. macOS `.app.zip`
4. optional Android `.apk`

## Important caveats

### Windows

The first milestone is a release-directory zip, **not** MSI / MSIX / Inno Setup.
That keeps the first packaging lane narrow and easy to validate.

### macOS

The first milestone is a zipped `.app`, **not** notarized DMG / PKG.
That means:
- usable for internal distribution
- not yet a polished public release flow

### Android

Treat APK as optional until Android runtime validation matters.
Do not let Android lane slow the desktop-first track.

## Recommended rollout order

1. land Linux + Windows + macOS CI artifacts
2. verify artifact structure and naming consistency
3. optionally enable Android APK lane on workflow dispatch
4. only after that discuss MSI / MSIX / DMG / notarization / code signing

## Blunt verdict

Right now the honest statement is:
- **Linux installable packaging is real and locally verified**
- **Windows and macOS packaging are still primarily CI-runner truths, but no longer “artifact-only” because packaged smoke is wired into their lanes**
- **Android packaging is feasible once SDK provisioning is added, but should remain optional**
