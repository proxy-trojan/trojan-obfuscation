# Client Linux Packaging Scaffold & Release Metadata Draft

## Goal

Freeze the Linux-first packaging decisions **before** Flutter desktop tooling is restored, so the first real packaging pass is mostly a fill-in-the-blanks exercise rather than a naming/metadata debate.

This document is intentionally pre-toolchain.
It defines:
- desktop scaffolding preparation checks
- Debian packaging metadata draft
- desktop entry details
- version naming rules
- package / executable / artifact naming rules
- release bundle and staging directory conventions

---

## 1. Naming matrix

Use one canonical name per surface instead of pretending one string can fit every layer.

- **Product / display name**: `Trojan Pro Client`
- **Dart / Flutter package name**: `trojan_pro_client`
- **Linux executable name**: `trojan_pro_client`
- **Debian package name**: `trojan-pro-client`
- **Desktop file id**: `trojan-pro-client.desktop`
- **Artifact stem**: `trojan-pro-client`
- **Install prefix**: `/opt/trojan-pro-client`
- **Launcher path**: `/usr/share/applications/trojan-pro-client.desktop`
- **Icon name**: `trojan-pro-client`
- **Expected icon target**: `/usr/share/icons/hicolor/256x256/apps/trojan-pro-client.png`

### Why split the names?

Because Linux packaging, Flutter, and desktop launchers want slightly different naming styles:

- Flutter / Dart packages want **snake_case**
- Debian packages want **kebab-case**
- human-facing UI wants **title case**

Trying to force one name across all three is how you end up with broken `Exec=` values or ugly package ids.

---

## 2. Version naming convention

### Canonical user-facing release label

Use this format for product/release communication:

- stable: `0.1.0`
- internal alpha: `0.1.0-internal-alpha.1`
- beta: `0.1.0-beta.2`
- nightly: `0.1.1-nightly.20260312`

Rule:
- stable releases are plain SemVer
- pre-release labels stay human-readable
- numeric suffix uses `.` instead of `-` to avoid unreadable artifact names

### Debian package version translation

Translate the user-facing label into a Debian-friendly version string:

- stable: `0.1.0-1`
- internal alpha: `0.1.0~internal.alpha.1-1`
- beta: `0.1.0~beta.2-1`
- nightly: `0.1.1~nightly.20260312-1`

Why this form:
- `~` keeps pre-release builds ordered **before** the final stable release
- trailing `-1` leaves room for Debian packaging revisions without renaming the product release itself

### Artifact naming examples

- release bundle label directory: `v0.1.0-internal-alpha.1/`
- Debian artifact: `trojan-pro-client_0.1.0~internal.alpha.1-1_amd64.deb`
- staging directory: `trojan-pro-client_0.1.0~internal.alpha.1-1_amd64/`

---

## 3. Desktop scaffolding preparation checklist

When Flutter tooling becomes available, do this in order.

### Tooling

1. `flutter doctor`
2. `flutter config --enable-linux-desktop`
3. `cd client && flutter create . --platforms=linux`

### Generated scaffold must exist

After `flutter create`, confirm these Linux desktop files exist:

- `client/linux/CMakeLists.txt`
- `client/linux/flutter/CMakeLists.txt`
- `client/linux/runner/main.cc`
- `client/linux/runner/my_application.cc`
- `client/linux/runner/my_application.h`

### Naming alignment checks

Before building, verify the generated Linux project still matches the chosen naming scheme:

- binary / target name should resolve to `trojan_pro_client`
- package/install surface should remain `trojan-pro-client`
- display name should remain `Trojan Pro Client`

### First build validation

Run:

```bash
cd client
flutter pub get
flutter analyze
flutter build linux --release
```

Expected bundle root:

```text
client/build/linux/x64/release/bundle/
```

Expected executable inside the bundle:

```text
client/build/linux/x64/release/bundle/trojan_pro_client
```

If that executable name differs, do **not** paper over it in packaging.
Fix the Linux scaffold naming first.

---

## 4. Release bundle / staging directory convention

Reserve this shape for Linux-first packaging work:

```text
client/build/linux/x64/release/bundle/

packaging/linux/
  assets/
    trojan-pro-client.png                 # optional until real icon lands
  artifacts/
    v0.1.0-internal-alpha.1/
      trojan-pro-client_0.1.0~internal.alpha.1-1_amd64.deb
  deb/
    control.in
    trojan-pro-client.desktop.in
    README.md
  staging/
    trojan-pro-client_0.1.0~internal.alpha.1-1_amd64/
  release-metadata.env
```

Rules:
- `client/build/.../bundle/` is the **source** bundle from Flutter
- `packaging/linux/staging/...` is temporary package assembly space
- `packaging/linux/artifacts/v<release-label>/` is the output handoff folder
- `packaging/linux/deb/` stores reusable metadata/templates, **not** generated staging output

This split avoids turning `deb/` into a junk drawer.

---

## 5. Debian metadata draft

The working draft lives in:

- `packaging/linux/release-metadata.env`
- `packaging/linux/deb/control.in`
- `packaging/linux/deb/trojan-pro-client.desktop.in`

### Draft package posture

- package name: `trojan-pro-client`
- architecture: `amd64` (first internal target)
- section: `net`
- priority: `optional`
- install prefix: `/opt/trojan-pro-client`
- current lane: `internal-alpha`

### Dependency posture

For now, treat package dependencies as an **initial draft**, not final truth.
The first real release-bundle pass should still confirm runtime dependencies from the built artifact.

That means the metadata can start opinionated, but the final dependency list should be validated after the first successful Linux bundle exists.

---

## 6. Desktop entry detail draft

The initial launcher should include at least:

- `Name=Trojan Pro Client`
- `Comment=Desktop-first Trojan-Pro client shell`
- `Exec=/opt/trojan-pro-client/trojan_pro_client`
- `TryExec=/opt/trojan-pro-client/trojan_pro_client`
- `Icon=trojan-pro-client`
- `Terminal=false`
- `Type=Application`
- `Categories=Network;Security;`
- `Keywords=Trojan;Proxy;Network;Security;`
- `StartupNotify=true`
- `StartupWMClass=trojan_pro_client`

Important:
- `Exec` should point to the **Linux executable name** (`trojan_pro_client`), not the Debian package name
- keep launcher filename kebab-case, executable snake_case, display name title case

That little naming triangle is annoying, but it is the correct annoying.

---

## 7. Hand-off rule for the first real packaging pass

Once Flutter Linux scaffolding exists, the packaging flow should be:

1. update `packaging/linux/release-metadata.env`
2. run Linux bundle build
3. verify `bundle/trojan_pro_client` exists
4. stage under `packaging/linux/staging/...`
5. render `control.in` + desktop entry template
6. emit the `.deb` into `packaging/linux/artifacts/v<release-label>/`

If that works, Linux-first packaging has crossed the line from “planned” to “repeatable internal workflow”.
