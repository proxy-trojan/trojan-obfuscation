# Desktop Validation Matrix

Use this matrix to record durable, comparable results for **v1.6+ internal beta**.

> Iter-1 hard gate focus: first-connect path truthfulness, next-action closure, diagnostics/support evidence quality.
> Iter-2 hard gate focus: recovery ladder truth (Top5 family actionability, recommendation closure, evidence-first order).

## Evidence pointers (current baseline)

- CI Smoke (main): <https://github.com/proxy-trojan/trojan-obfuscation/actions/runs/24648027070>
- Client Packaging (main): <https://github.com/proxy-trojan/trojan-obfuscation/actions/runs/24648027074>
- Build and Release (main): <https://github.com/proxy-trojan/trojan-obfuscation/actions/runs/24648027071>
- Local command bundle (Iter-1): `./scripts/validate_iter1_first_connect.sh` (latest run: PASS)
- Local command bundle (Iter-2): `./scripts/validate_iter2_recovery_ladder.sh` (latest run: PASS)
- Local command bundle (Iter-3): `./scripts/validate_iter3_truthful_daily_use.sh` (latest run: PASS)

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

## Iter-2 Recovery Ladder 1.0

| Area (Iter-2 gate) | Linux | Windows | macOS | Notes |
|------|-------|---------|-------|-------|
| Top5 failure family ladder is actionable (launch/config/environment/connect/user_input) | [x] | [x] | [x] | recovery policy + next-action tests landed on main |
| Recommendation one-click closure (destination + fallback) | [x] | [x] | [x] | Dashboard/Profiles recommendation closure semantics |
| Evidence-first rule for stop-pending / stale / residual | [x] | [x] | [x] | runtime action safety + operator advice tests |
| Recovery telemetry closure (suggested -> acted -> outcome) | [x] | [x] | [x] | analytics mapper/service + snapshot script + PR #49 |
| Recovery ladder command bundle reproducibility | [x] | [x] | [x] | `./scripts/validate_iter2_recovery_ladder.sh` PASS |

---

## Suggested per-run note format

For each platform update, append a short note entry:

- **Date**
- **Platform**
- **Version/commit**: e.g. `v1.6.0-beta.N / <sha>`
- **Result**: Pass / Fail / Skip
- **Evidence pointers**:
  - CI run URL(s)
  - local command bundle result (Iter-1 / Iter-2)
  - screenshot/log path when available
- **Blocking reason** (if Fail/Skip): reproducible step + expected vs actual
- **Recovery ladder focus**: Top5 family / recommendation closure / evidence-first row touched

Example:

- `2026-04-20 | macOS | v1.6.0-beta.2 (2e29c3a) | Pass | CI packaging + validate_iter1_first_connect.sh + validate_iter2_recovery_ladder.sh | focus: recommendation closure`
- `2026-04-20 | Windows | v1.6.0-beta.2 (2e29c3a) | Pass | CI packaging + smoke gate + validate_iter2_recovery_ladder.sh | focus: Top5 family ladder`
- `2026-04-20 | Linux | v1.6.0-beta.2 (2e29c3a) | Pass | CI smoke + packaging + local command bundle | focus: evidence-first rule`
