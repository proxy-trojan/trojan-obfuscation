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

Runner-backed evidence now in hand:
- `Client Packaging` run `24404269034` (`headSha: 08d947a8645a6bacd6881f29ab059ef9b539397a`) is green on desktop lanes
- macOS lane `71283069883`: `Packaged smoke (macOS app zip)` passed
- Linux lane `71283069809`: `Packaged smoke (Linux bundle)` passed
- Windows lane `71283069793`: `Packaged smoke (Windows zip)` passed

Reference: <https://github.com/proxy-trojan/trojan-obfuscation/actions/runs/24404269034>

## Current reality by platform

1. **Linux**: packaging + release-truth + packaged smoke are green in runner lane `71246912761`
2. **Windows**: packaging + release-truth + packaged smoke are green in runner lane `71246912805`
3. **macOS**: packaging + release-truth + packaged smoke are green in runner lane `71246912751`
4. **Android**: supported in release flow (this run kept `build_android=false`, lane skipped by design)

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
