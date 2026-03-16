# Desktop Validation Matrix

Use this matrix to record manual validation results for `v1.3.0-desktop-beta`.

| Area | Linux | Windows | macOS | Notes |
|------|-------|---------|-------|-------|
| App launch | [ ] | [ ] | [ ] | |
| Close/minimize/quit semantics | [ ] | [ ] | [ ] | |
| Tray `Open` | [ ] | [ ] | [ ] | |
| Tray `Connect` / `Disconnect` gating | [ ] | [ ] | [ ] | |
| Duplicate launch mitigation | [ ] | [ ] | [ ] | |
| Profile CRUD | [ ] | [ ] | [ ] | |
| Secure storage / password flow | [ ] | [ ] | [ ] | |
| Runtime connect / disconnect | [ ] | [ ] | [ ] | |
| Failure summary / recovery | [ ] | [ ] | [ ] | |
| Diagnostics preview | [ ] | [ ] | [ ] | |
| Diagnostics export | [ ] | [ ] | [ ] | |
| Packaging snapshot export | [ ] | [ ] | [ ] | |
| Update-check stub behavior | [ ] | [ ] | [ ] | |
| Known limitations reviewed | [ ] | [ ] | [ ] | |

## Suggested note format

- **Pass**: short confirmation + environment
- **Fail**: clear repro step + screenshot/log path + suspected blocker
- **Skip**: explicit reason (`headless`, `tray unavailable`, `platform packaging not built`, etc.)
