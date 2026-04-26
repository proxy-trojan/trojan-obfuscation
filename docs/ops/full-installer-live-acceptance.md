# Full installer live acceptance

This runbook describes the minimum live acceptance pass for Full Installer v1.

## Scope

Validate that a real host can:
1. pass installer preflight
2. run installer apply
3. expose `www` and `edge` surfaces
4. export a usable client bundle
5. use `tp` for day-2 checks

## Acceptance checklist

- DNS resolves correctly for `www` and `edge`
- ports 80 / 443 reachable
- required provider env exported
- `bash scripts/install/install-kernel.sh --www-domain ... --edge-domain ... --dns-provider ... --apply`
- `tp status --json`
- `tp validate`
- `tp export-client-bundle ...`

## Evidence to retain

- installer stdout/stderr
- rendered `install-manifest.json`
- rendered `config.json`
- rendered `Caddyfile`
- generated client bundle JSON
- `tp validate` output
