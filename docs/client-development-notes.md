# Client Development Notes

## Status

Draft

## Current implementation scope

The client workspace currently provides:
- dashboard/status shell
- profile create/edit/import/export flow
- settings state model
- fake controller boundary
- secure storage abstraction (memory stub)
- local state store abstraction (memory stub)
- profile/settings load-save lifecycle through local state store
- diagnostics JSON preview

## Current limitations

- no real Flutter runtime validation has been performed in this repository environment
- no real file-backed persistent storage adapter yet (only abstraction + memory stub)
- no real connectivity engine integration yet
- no platform-native secure storage backend yet
- no desktop packaging/update flow yet

## Recommended next implementation steps

1. real file-backed persistent profile/settings storage adapter
2. diagnostics save-to-file abstraction
3. controller event log/timeline panel
4. real secure storage adapters per platform
5. Flutter-enabled validation (`flutter pub get`, `flutter analyze`, `flutter run`)

## Rule for upcoming work

Do not couple the UI directly to low-level runtime internals.
Keep building against the local controller boundary.
