# Trojan-Pro Client

Desktop-first, mobile-ready client shell for the Trojan-Pro project.

## Current status

This is **Phase A client shell scaffolding**.
Current scope focuses on product-layer concerns:
- profile management shell
- profile create/edit/import/export flow
- settings/state model
- fake controller boundary
- secure storage abstraction
- diagnostics export preview

It does **not** yet embed a real connectivity/runtime engine.

## Planned targets
- Windows
- macOS
- Linux
- later: iOS / Android

## When Flutter is available

```bash
cd client
flutter pub get
flutter run -d linux   # or windows / macos
```

## Current architecture

See:
- `../docs/client-product-architecture.md`
- `../docs/adr-client-product-stack.md`
