# Trojan-Pro Client

Desktop-first, mobile-ready client shell for the Trojan-Pro project.

## Current status

This is **Phase A client shell scaffolding**.
Current scope focuses on product-layer concerns:
- dashboard / status shell
- profile management shell
- profile create/edit/import/export flow
- settings/state model
- fake controller boundary
- grouped controller timeline for action/progress/result visibility
- typed controller boundary contract (command/result/telemetry)
- adapter-backed fake/real shell controller seam
- real shell adapter launch/config + first executable connect-path skeleton (with binary probe)
- runtime session visibility (pid / last exit / log tail)
- secure storage abstraction + Trojan password handling (set/rotate/view/clear)
- portable profile export that excludes secret material
- packaging/update workflow skeleton + dry-run manifest/metadata snapshots
- packaging snapshot export (manifest / metadata / rollback plan) with export status/history
- diagnostics export preview

It does **not** yet embed a real connectivity/runtime engine.

## Planned targets
- Windows
- macOS
- Linux
- later: iOS / Android

## Local validation

```bash
cd client
flutter pub get
flutter analyze
flutter run -d linux
flutter build linux --release
```

Cross-platform desktop outputs are prepared through CI runners:
- Windows runner → `flutter build windows --release`
- macOS runner → `flutter build macos`

If you want to exercise the real shell adapter skeleton:

```bash
export TROJAN_CLIENT_ENABLE_REAL_ADAPTER=1
export TROJAN_CLIENT_BINARY=/absolute/path/to/trojan   # optional if auto-discovery is wrong
```

## Packaging outputs

Locally verified now:
- Linux `.deb`
- Linux release-bundle `.tar.gz`

CI matrix targets:
- Windows release `.zip`
- macOS `.app.zip`
- optional Android `.apk`

**EN**
- As of 2026-03-12, GitHub Actions `Build and Release` has validated Linux / Windows / macOS client packaging in CI.
- Desktop client artifacts are now part of the same delivery flow as core multi-platform artifacts.

**中文**
- 截至 2026-03-12，GitHub Actions `Build and Release` 已验证 Linux / Windows / macOS 的 client 打包链路。
- 桌面端 client 产物现在已经并入与 core 多平台产物一致的统一交付流程。

## Internal alpha handoff

Use these docs as the current finish-line packet:
- `../docs/client-finish-line-packet.md`
- `../docs/client-internal-alpha-checklist.md`
- `../docs/client-runtime-smoke-test.md`
- `../docs/client-wrap-up-summary-2026-03-11.md`
- `../docs/client-ui-ux-checklist.md`
- `../docs/client-packaging-readiness.md`
- `../docs/client-linux-packaging-plan.md`
- `../docs/client-linux-packaging-scaffold.md`
- `../docs/client-packaging-next-actions.md`
- `../docs/client-cross-platform-packaging.md`

## Current architecture

See:
- `../docs/client-product-architecture.md`
- `../docs/adr-client-product-stack.md`
