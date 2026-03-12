# Client Packaging Readiness

## Current answer

**Linux installable packaging is now real and locally verified.**

The environment is no longer blocked on missing Flutter tooling.
The client workspace now has generated desktop scaffolding for `linux/`, `macos/`, and `windows/`, plus Android scaffold as an optional lane.

## Current reality by platform

1. **Linux**: fully working on the current machine (`flutter analyze` / `flutter build linux --release` / `.deb` packaging / install-uninstall smoke test all verified).
2. **Windows**: packaging target is valid, but must run on a Windows host or CI runner.
3. **macOS**: packaging target is valid, but must run on a macOS host or CI runner.
4. **Android**: optional lane; requires Android SDK provisioning before `flutter build apk` can succeed.
5. **Public-grade installers** (`.msix`, notarized `.dmg`, signed `.pkg`) are still future work; the current milestone is internal-distribution-ready artifacts.

## What is already ready

The product-layer groundwork is already strong enough to justify moving into packaging once the build chain exists:
- client shell and navigation
- profile flow
- secure-storage password flow
- diagnostics export
- packaging/update workflow UI
- runtime controller seam
- real adapter first executable skeleton

So the remaining work is now mostly **CI runner packaging lanes + runtime validation + installer/signing polish**, not product direction.

## Shortest path to repeatable packages

For the actual Linux-first path, follow:
- `docs/client-linux-packaging-plan.md`
- `docs/client-linux-packaging-scaffold.md`
- `docs/client-packaging-next-actions.md`
- `packaging/linux/README.md`
- `packaging/linux/release-metadata.env`
- `scripts/build-client-linux-package.sh`


### Step 1 — Validate the client before packaging

```bash
cd client
flutter pub get
flutter analyze
flutter run -d linux
```

### Step 2 — Run internal alpha smoke test

Follow:
- `docs/client-internal-alpha-checklist.md`
- `docs/client-runtime-smoke-test.md`
- `docs/client-ui-ux-checklist.md`

### Step 3 — Produce platform builds

For local Linux validation:

```bash
cd client
flutter build linux --release
```

For CI runner targets:
- Windows runner: `flutter build windows --release`
- macOS runner: `flutter build macos`
- Ubuntu + Android SDK: `flutter build apk --release`

### Step 4 — Wrap the build into installable/distributable artifacts

Current first targets:
- Linux: `.deb` + `.tar.gz` bundle
- Windows: `.zip` of the release directory
- macOS: `.app.zip`
- Android: `.apk` (optional lane)

Later targets:
- Windows: MSIX / installer
- macOS: notarization / DMG / PKG
- Linux: AppImage / signed repository flow

## Recommended packaging strategy

### First milestone

**Linux-first internal package (already achieved)**

Why it landed first:
- fastest validation path in the current working environment style
- easiest to verify runtime adapter behavior
- best fit for early internal-alpha distribution

### Next milestones

1. Windows package flow in CI
2. macOS package flow in CI
3. optional Android APK lane in CI
4. signed / notarized release handling
5. update channel automation

## Practical conclusion

The current project has crossed the line from packaging planning into **real Linux packaging + cross-platform CI preparation**.

If the next phase is "make client delivery repeatable", the work should now shift to:

1. CI matrix packaging for Linux / Windows / macOS
2. optional Android SDK provisioning + APK lane
3. runtime smoke validation on real GUI-capable runners
4. later installer/signing polish
