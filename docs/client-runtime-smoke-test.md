# Client Runtime Smoke Test

## Purpose

A minimal, repeatable smoke test for the Trojan-Pro Flutter client once Flutter is available.

This test is designed to answer one question only:

> Can the desktop client complete a first end-to-end internal-alpha flow?

---

## Preconditions

- Flutter SDK installed
- Desktop target enabled (`linux`, `macos`, or `windows`)
- `trojan` binary built and executable
- Test profile/server parameters available

Optional environment variables:

```bash
# v1.4.0 first cut: backend mode defaults to auto on desktop.
# You can still force modes explicitly when validating behavior.
export TROJAN_CLIENT_BACKEND_MODE=real   # or stub
export TROJAN_CLIENT_ENABLE_REAL_ADAPTER=1  # legacy compatibility path
export TROJAN_CLIENT_BINARY=/absolute/path/to/trojan
export KEEP_SMOKE_ARTIFACTS=1
```

Automation helpers:

```bash
# source/build-time runtime smoke
./scripts/run-client-runtime-smoke.sh

# packaged desktop smoke (artifact-first)
python3 scripts/client_packaged_smoke.py \
  --platform linux \
  --artifact-root packaging/linux/artifacts/v1.4.0-beta.3 \
  --mode smoke
```

What the helpers currently verify:
- `./scripts/run-client-runtime-smoke.sh`
  - `flutter analyze`
  - `flutter test`
  - `flutter build linux --debug`
  - real `trojan` client preflight with a generated config
  - desktop app launch smoke when a GUI is available
- `scripts/client_packaged_smoke.py`
  - resolves the packaged desktop artifact for a target platform
  - extracts the artifact into a temporary validation root
  - resolves the packaged executable/app bundle
  - runs a bounded desktop launch smoke window on the packaged app

In headless environments, the packaged smoke helper will explicitly report Linux GUI launch as skipped unless `xvfb-run` or a real `DISPLAY`/`WAYLAND_DISPLAY` is available.

---

## Step 1 — Launch Client

Manual path:

```bash
cd client
flutter pub get
flutter analyze
flutter run -d linux
```

Scripted path:

```bash
./scripts/run-client-runtime-smoke.sh
```

Expected:
- app starts
- dashboard renders
- no immediate crash

If the environment is headless, treat `flutter build linux --debug` + trojan preflight as the minimum non-GUI signal, and record the GUI launch step as blocked by missing display infrastructure rather than by app failure.

---

## Step 2 — Prepare Profile

Inside the client:

1. Create or import a profile
2. Confirm server host / port / SNI / local socks port are populated
3. Store Trojan password via secure-storage flow

Expected:
- profile saves successfully
- password state shows as stored

---

## Step 3 — Verify Controller State

Check Dashboard / Profile details:

- runtime mode
- endpoint hint
- controller health
- runtime session block

Expected:
- runtime mode is `real-runtime-boundary` when real adapter is selected
- fallback/degraded cases use explicit `stubbed-local-boundary-*` modes (not silently pretending to be real)
- health is not permanently `unavailable`

---

## Step 4 — Connect

Click **Connect**.

Expected:
- status summary reports process launch attempt
- runtime session shows PID
- config path appears
- stdout/stderr tail begins updating when output exists
- no silent failure

If connect fails, record:
- runtime health text
- last error
- diagnostics preview/export bundle

---

## Step 5 — Disconnect

Click **Disconnect**.

Expected:
- process terminates
- PID clears
- config file is cleaned up
- status summary reflects disconnect request/result truthfully (`stop requested` while pending, `disconnected` after exit)

---

## Step 6 — Export Diagnostics

1. Open Diagnostics page
2. Generate preview
3. Export bundle

Expected diagnostics content should include:
- selected profile snapshot
- secure storage backend/key count
- controller telemetry
- runtime config
- runtime health
- runtime session
- packaging workflow/export history

---

## Step 7 — Packaging Snapshot Export

1. Open Packaging page
2. Export snapshots

Expected:
- manifest export target returned
- update metadata export target returned
- rollback plan export target returned
- export history updates in the UI

---

## Packaged smoke policy

For `v1.4.0-beta.3`, packaged smoke is intentionally narrower than the full manual runtime checklist above.

Pass criteria for packaged smoke:
- the expected packaged artifact exists for the target platform
- extraction succeeds
- the packaged executable/app bundle is discoverable
- the packaged app stays alive for the smoke window on a GUI-capable runner
- or, on headless Linux, the step reports an explicit environment-limited skip instead of pretending to be a pass

This packaged smoke is a **release/CI gate**, not a substitute for full operator-like runtime validation.

## Pass Criteria

The full runtime smoke test passes if:

- app launches
- profile/password flow works
- health probe works
- connect starts a process
- disconnect stops it
- diagnostics export succeeds
- packaging snapshot export succeeds

---

## Failure Capture Template

If the smoke test fails, capture:

- platform
- Flutter version
- target device
- trojan binary path
- runtime mode
- status message
- last error
- last exit code
- stdout tail
- stderr tail
- exported diagnostics bundle path

---

## Current limitations (Sprint 1)

- In headless environments without `DISPLAY`/`WAYLAND_DISPLAY` and without `xvfb-run`, GUI launch smoke is expected to be reported as **skipped**.
- `sessionReady` currently depends on local SOCKS port observability; some environments may stay in `alive` longer even when process startup succeeded.
- The smoke script proves a high-signal local runtime path, but it is not yet a substitute for real staging beta validation on operator-like desktop environments.
