# Client Packaging Readiness

## Current answer

Desktop client packaging is now **real and CI-validated**.

## Verified status

GitHub Actions `Build and Release` has verified client packaging for:

- Linux `.deb`
- Linux `.tar.gz` bundle
- Windows `.zip`
- macOS `.app.zip`
- Android `.apk`

The same workflow also validates:
- checksum files (`.sha256`)
- expected artifact presence
- package sanity checks

## Current reality by platform

1. **Linux**: locally buildable and releasable
2. **Windows**: built through GitHub Actions runners
3. **macOS**: built through GitHub Actions runners
4. **Android**: supported in release flow

## Local validation

```bash
cd client
flutter pub get
flutter analyze
flutter build linux --release
```

## Related files

- `client/README.md`
- `docs/client-cross-platform-packaging.md`
- `docs/client-product-architecture.md`
- `packaging/linux/README.md`
- `scripts/build-client-linux-package.sh`
