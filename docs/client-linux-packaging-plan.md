# Client Linux-First Packaging Plan

## Goal

Produce the first **usable installable Linux package** for the Trojan-Pro client once Flutter desktop tooling is available.

This plan is intentionally Linux-first because it is the shortest path to:
- validating the desktop runtime boundary
- validating the real adapter flow
- shipping an internal package quickly

---

## Deliverable target

### First package target

Preferred order:
1. Linux desktop release build directory
2. `.deb` package (preferred if metadata is ready)
3. AppImage (acceptable alternate internal distribution format)

---

## Preconditions

Before packaging begins, all of the following must be true:

- Flutter SDK available
- Dart CLI available
- Desktop Flutter scaffolding exists in `client/`
- `flutter analyze` passes
- `flutter run -d linux` succeeds
- internal alpha smoke test passes

Required docs:
- `docs/client-packaging-readiness.md`
- `docs/client-internal-alpha-checklist.md`
- `docs/client-runtime-smoke-test.md`
- `docs/client-ui-ux-checklist.md`

---

## Phase 1 — Toolchain bootstrap

From `client/`:

```bash
flutter doctor
flutter config --enable-linux-desktop
flutter create . --platforms=linux
flutter pub get
flutter analyze
flutter run -d linux
```

Exit condition:
- Linux desktop shell launches successfully

---

## Phase 2 — Release build validation

```bash
cd client
flutter build linux --release
```

Expected output:
- `client/build/linux/x64/release/bundle/`

Validation:
- app launches from release bundle
- profile flow works
- password flow works
- real adapter path can be enabled and tested
- diagnostics export works

---

## Phase 3 — Internal package layout

Suggested output layout:

```text
packaging/linux/
  assets/
  deb/
  staging/
  artifacts/
  release-metadata.env
```

Suggested artifact naming:

```text
artifacts/v0.1.0-internal-alpha.1/
trojan-pro-client_0.1.0~internal.alpha.1-1_amd64.deb
```

Additional scaffold reference:
- `docs/client-linux-packaging-scaffold.md`
- `packaging/linux/release-metadata.env`
- `packaging/linux/deb/control.in`
- `packaging/linux/deb/trojan-pro-client.desktop.in`

---

## Phase 4 — Debian package path

Recommended first package shape:
- package the release bundle
- include desktop entry
- include icon
- install under `/opt/trojan-pro-client`
- add launcher entry under `/usr/share/applications/`

Minimum metadata:
- package name: `trojan-pro-client`
- version: `0.1.0-internal-alpha-1`
- arch: `amd64`
- maintainer: internal
- description: desktop client for Trojan-Pro internal alpha

---

## Phase 5 — Validation after packaging

After package creation:

1. install the package on a clean Linux environment
2. launch the app from launcher and terminal
3. run one profile/password/connect/disconnect flow
4. export diagnostics
5. verify uninstall is clean enough for internal use

---

## Practical recommendation

### Do first
- generate Linux Flutter scaffolding
- build release bundle
- verify real adapter behavior from release bundle

### Do second
- wrap into `.deb`

### Do later
- AppImage
- CI automation
- signed release process
- Windows/macOS packaging

---

## Definition of success

Linux-first packaging is successful when:

- a release build exists
- the app launches outside Flutter dev mode
- the core flow works in the built app
- a `.deb` or equivalent installable artifact exists
- the package is usable by an internal tester without manual project setup
