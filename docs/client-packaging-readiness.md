# Client Packaging Readiness

## Current answer

Desktop client packaging is now **real**, and the current `v1.4.0-beta.3` lane has **executable CI gates** for release truth and packaged smoke.

## Verified status

Current repository reality:

- Linux `.deb` and `.tar.gz` bundle are locally buildable and have local artifact evidence
- Windows `.zip` packaging lane exists in GitHub Actions
- macOS `.app.zip` packaging lane exists in GitHub Actions
- Android `.apk` remains supported in the release flow

The desktop packaging flow now also defines these gates:
- release-truth validation via `scripts/validate_client_release_truth.py`
- packaged smoke via `scripts/client_packaged_smoke.py`
- checksum / artifact presence / package sanity validation

What is **not** claimed yet:
- fresh runner-backed evidence for every current desktop lane in this exact `beta.3` iteration
- blanket “fully CI-validated” language beyond the evidence currently in hand

## Current reality by platform

1. **Linux**: locally buildable and locally smoke-checked at the artifact level; GUI launch may be environment-limited on headless hosts
2. **Windows**: packaging lane exists in GitHub Actions and now includes packaged smoke gating
3. **macOS**: packaging lane exists in GitHub Actions and now includes packaged smoke gating
4. **Android**: supported in release flow

## Local validation

```bash
cd client
flutter pub get
flutter analyze
flutter build linux --release

cd ..
python3 scripts/validate_client_release_truth.py
python3 scripts/client_packaged_smoke.py \
  --platform linux \
  --artifact-root packaging/linux/artifacts/v1.4.0-beta.3 \
  --mode smoke \
  --allow-skip
```

## Related files

- `client/README.md`
- `docs/client-cross-platform-packaging.md`
- `docs/client-product-architecture.md`
- `docs/v1.2.0-release-candidate-checklist.md`
- `packaging/linux/README.md`
- `scripts/build-client-linux-package.sh`
- `scripts/verify-artifact-checksums.sh`
- `scripts/smoke-check-client-artifacts.sh`
- `scripts/validate_client_release_truth.py`
- `scripts/client_packaged_smoke.py`
