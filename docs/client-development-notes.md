# Client Development Notes

## Status

Draft

## Current implementation scope

The client workspace currently provides:
- dashboard/status shell
- profile create/edit/import/export flow
- settings state model
- adapter-backed controller boundary with typed command/result/telemetry contract
- real shell adapter can now render trojan client launch/config plans and attempt a first executable connect path (config write + process launch/stop + health probe)
- runtime session state now captures pid / config path / last exit / stdout-stderr tail
- controller event timeline with action/progress/result grouping (fake event stream)
- secure storage abstraction with memory + flutter_secure_storage-backed adapters
- local state store abstraction with memory + desktop file-backed adapters
- profile/settings load-save lifecycle through local state store
- diagnostics JSON preview
- diagnostics export action abstraction with memory + desktop file-backed adapters
- packaging/update workflow skeleton with per-platform readiness matrix
- release manifest + update metadata dry-run snapshots
- packaging snapshot export for manifest / update metadata / rollback plan
- packaging export status + recent history tracking
- profile Trojan password can be stored separately via secure storage boundary
- startup reconciles `hasStoredPassword` against real secure storage presence
- portable profile export explicitly excludes Trojan password material
- import handoff warns when source device had a stored password but this device does not
- secret UX includes set/update/rotate/view/clear + destructive-action confirmation
- profile removal also clears stored Trojan password when present
- diagnostics payload includes controller + packaging/update snapshots + export history

## Current limitations

- no real Flutter runtime validation has been performed in this repository environment
- no real connectivity engine integration yet
- no real desktop packaging/update automation yet (current state is workflow skeleton only)
- flutter_secure_storage integration has not been runtime-validated in a Flutter-enabled desktop/mobile environment yet
- secure-storage reconciliation path has not been runtime-validated yet
- diagnostics export / file-backed state paths have not been runtime-validated in a Flutter-enabled desktop environment yet

## Recommended next implementation steps

1. Flutter-enabled validation (`flutter pub get`, `flutter analyze`, `flutter run`)
2. run `docs/client-runtime-smoke-test.md`
3. close the remaining issues discovered by the first smoke run
4. real desktop packaging/update automation
5. packaging CI + rollback metadata validation

## Rule for upcoming work

Do not couple the UI directly to low-level runtime internals.
Keep building against the local controller boundary.

## Finish-line docs

- `docs/client-finish-line-packet.md`
- `docs/client-internal-alpha-checklist.md`
- `docs/client-runtime-smoke-test.md`
- `docs/client-wrap-up-summary-2026-03-11.md`
