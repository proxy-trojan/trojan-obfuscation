# Android Packaging

This directory stores Android client packaging outputs.

## Current posture

Android is an **optional lane**.
Desktop-first remains the primary product track.

## First milestone

- provision Android SDK on CI runner
- build `app-release.apk`
- collect it under the versioned artifacts directory

## Artifact convention

```text
packaging/android/artifacts/v<version-label>/
  trojan-pro-client_<version-label>_android-release.apk
```
