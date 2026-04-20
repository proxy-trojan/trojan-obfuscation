# Desktop Validation Matrix

Use this matrix to record durable, comparable results for **v1.6+ internal beta**.

> Iter-1 hard gate focus: first-connect path truthfulness, next-action closure, diagnostics/support evidence quality.

## Evidence pointers (current baseline)

- CI Smoke (main): <https://github.com/proxy-trojan/trojan-obfuscation/actions/runs/24648027070>
- Client Packaging (main): <https://github.com/proxy-trojan/trojan-obfuscation/actions/runs/24648027074>
- Build and Release (main): <https://github.com/proxy-trojan/trojan-obfuscation/actions/runs/24648027071>
- Local command bundle: `./scripts/validate_iter1_first_connect.sh` (latest run: PASS)

---

## Iter-1 A1 First Connect Path 1.0

| Area (Iter-1 gate) | Linux | Windows | macOS | Notes |
|------|-------|---------|-------|-------|
| App launch | [x] | [x] | [x] | CI packaging jobs succeeded for desktop artifacts |
| Profile import/create baseline | [x] | [x] | [x] | Covered by Profiles action-gating flow + packaging smoke lane |
| Password storage truth (secure vs fallback) | [x] | [x] | [x] | UI + diagnostics export semantics validated in test gate |
| Readiness blocked => connect blocked + next action | [x] | [x] | [x] | `profiles_page_action_gating_test.dart` |
| One-click Connect Test CTA (Profiles) | [x] | [x] | [x] | `Connect Test` / `Connect Test (stub path)` behavior validated |
| Runtime-true only success accounting | [x] | [x] | [x] | controller/test hardening for missing probe evidence |
| Connect timeline phase visibility | [x] | [x] | [x] | `connect_timeline_card_test.dart` |
| Failure family + next action closure | [x] | [x] | [x] | timeline + profile policy tests |
| Disconnect/Exit truthfulness (wait for exit confirmation) | [x] | [x] | [x] | stop-pending / exit confirmation semantics validated |
| Diagnostics support bundle export | [x] | [x] | [x] | diagnostics export tests + packaging gate |
| Runtime-proof artifact gating by posture | [x] | [x] | [x] | evidence-grade vs shell-grade policy semantics validated |
| Iter-1 command bundle reproducibility | [x] | [x] | [x] | `scripts/validate_iter1_first_connect.sh` PASS |

---

## Suggested per-run note format

For each platform update, append a short note entry:

- **Version/commit**: e.g. `v1.6.0-beta.N / <sha>`
- **Result**: Pass / Fail / Skip
- **Evidence**: CI URL / local log path / screenshot path
- **Blocking reason** (if Fail/Skip): reproducible step + expected vs actual

Example:

- `2026-04-20 | macOS | v1.6.0-beta.2 (2e29c3a) | Pass | CI packaging + local validate_iter1_first_connect.sh`
- `2026-04-20 | Windows | v1.6.0-beta.2 (2e29c3a) | Pass | CI packaging + smoke gate`
- `2026-04-20 | Linux | v1.6.0-beta.2 (2e29c3a) | Pass | CI smoke + packaging + local command bundle`
