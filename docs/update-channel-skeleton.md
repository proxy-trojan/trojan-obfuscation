# Update Channel Skeleton (v1.3.0)

## Purpose

`v1.3.0` introduces the **product boundary** for future self-update work without claiming that desktop self-update is production-ready.

This milestone is about:

- making the update channel visible in product settings
- defining a release metadata contract
- exercising a local/stub update-check flow
- documenting what is **not** implemented yet

## Current channels

- `stable`
- `beta`
- `nightly`

## Current product behavior

- Settings shows the selected update channel and auto-check preference
- Packaging/Settings surfaces expose a **Check for Updates** stub action
- The stub records a timestamp and summary locally
- Exported release/update metadata includes a contract version (`v0-draft`)

## Release metadata contract (draft)

Current `UpdateMetadataSnapshot` fields:

- `generatedAt`
- `channel`
- `updateChecksEnabled`
- `currentVersionLabel`
- `manifestArtifactName`
- `contractVersion`
- `summary`

Current `ReleaseManifest` fields:

- `versionLabel`
- `channel`
- `generatedAt`
- `artifactPrefix`
- `platforms[]`
- `rollbackHint`

## What v1.3.0 does NOT promise yet

- no real remote release feed
- no signed update metadata verification
- no background downloader
- no installer patching / in-place update flow
- no platform-native auto-updater integration
- no public-beta release channel service contract beyond the exported draft metadata

## Why this still matters

This skeleton prevents future updater work from starting as an unbounded UI hack.

It gives the client a stable place to attach:

- release metadata fetchers
- channel policy enforcement
- installer/updater orchestration
- rollback-aware release workflows

## Related files

- `client/lib/features/packaging/domain/update_workflow_state.dart`
- `client/lib/features/packaging/domain/update_metadata_snapshot.dart`
- `client/lib/features/packaging/application/packaging_store.dart`
- `client/lib/features/packaging/presentation/packaging_page.dart`
- `client/lib/features/settings/presentation/settings_page.dart`
