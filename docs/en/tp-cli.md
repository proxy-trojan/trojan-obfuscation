# tp CLI

`tp` is the day-2 management surface for a manifest-backed full installer deployment.
`tpctl` is a compatibility alias that resolves to the same command.

## Core commands

- `tp status`
- `tp validate`
- `tp rotate-password`
- `tp set-web-mode static`
- `tp set-web-mode upstream --upstream https://origin.example.com`
- `tp reconfigure-dns-provider <provider>`
- `tp export-client-bundle --direct <file> --proxy <file> --reject <file> --output <file>`

## Notes

- Use `--root-prefix <path>` for staged validation or fixture-based testing.
- `status --json` prints the current install manifest.
- `validate` checks manifest + Trojan config + Caddyfile presence.
- `export-client-bundle` reuses the manifest-backed bundle export path.
