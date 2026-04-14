# Release Playbook

## Purpose

This document defines the formal release process for Trojan-Pro.

---

## Branch policy

- `develop`: active integration branch
- `main`: stable release branch
- releases are cut only from `main`

---

## Release types

### Minor release
Examples: `v1.2.0`, `v1.3.0`

Use when:
- shipping new user-facing capability
- introducing product-level changes
- graduating milestone scope

### Patch release
Examples: `v1.1.1`, `v1.2.1`

Use when:
- fixing release packaging issues
- fixing CI / artifact / installer issues
- fixing targeted regressions without changing roadmap scope

---

## Pre-release checklist

Before tagging:
- `develop` merged into `main`
- `main` is green
- changelog updated
- release notes scope understood
- no known blocker in packaging / validation
- release candidate checklist reviewed: `docs/v1.2.0-release-candidate-checklist.md`
- checksum helper passes: `scripts/verify-artifact-checksums.sh artifacts`
- release truth helper passes: `python3 scripts/validate_client_release_truth.py`
- desktop artifact smoke helper passes: `scripts/smoke-check-client-artifacts.sh artifacts --platforms linux,windows,macos`
- desktop packaged smoke helper is wired into `client-packaging` CI before artifact upload:
  - `python3 scripts/client_packaged_smoke.py --platform <linux|windows|macos> --artifact-root <...> --mode smoke`
  - in headless Linux environments, GUI launch still depends on `DISPLAY` / `WAYLAND_DISPLAY` or `xvfb-run`

---

## Release procedure

### 1. Sync branches

```bash
git checkout main
git pull --ff-only origin main
git merge --ff-only develop
git push origin main
```

### 2. Create tag

```bash
git tag -a vX.Y.Z -m "Release vX.Y.Z"
git push origin refs/tags/vX.Y.Z
```

### 3. Wait for GitHub Actions

Workflow:
- `.github/workflows/release.yml`

Expected:
- core multi-platform artifacts
- client multi-platform artifacts
- Android APK on tagged releases
- per-platform client release-truth validation passes
- per-platform client packaged smoke passes
- `validate-artifacts` passes before release publish

### 4. Verify release page

Check:
- release exists on GitHub
- assets uploaded
- `.sha256` files uploaded
- release notes render correctly

---

## Post-release verification

- download one core artifact
- download one client artifact
- verify checksum
- spot-check archive contents
- confirm release tag points to intended commit

---

## Rollback guidance

### If tag run fails before release publish
- fix in `develop`
- merge to `main`
- move or replace tag only if release was not published

### If release already published and is bad
- do **not** rewrite history casually
- publish a patch release instead
- reserve tag rewriting for clearly unpublished / invalid attempts only

---

## Rules

- do not release from `develop`
- do not release while `main` is red
- do not publish without changelog update
- do not hide failed release runs; fix forward visibly
