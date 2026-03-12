# Windows Packaging

This directory stores Windows client packaging outputs.

## First milestone

- build on a Windows runner
- package the Flutter release directory as a `.zip`

## Artifact convention

```text
packaging/windows/artifacts/v<version-label>/
  trojan-pro-client_<version-label>_windows-x64.zip
```

## Notes

This is intentionally **not** MSIX / MSI yet.
The first goal is repeatable internal distribution, not polished installer UX.
