# Day-2 operations — `tp` CLI

This guide explains the day-2 management surface provided by `tp`.

- `tp` is installed at `/usr/local/bin/tp` during installer `--apply`
- `tpctl` is a compatibility alias

> Important
>
> Some mutation commands update the **manifest/env** only. They do **not** automatically re-render configs or restart services unless the operator does so.

---

## Status and validation

```bash
tp status
```

```bash
tp status --json
```

```bash
tp validate
```

`validate` checks presence of:
- `/etc/trojan-pro/install-manifest.json`
- `/etc/trojan-pro/config.json`
- `/etc/caddy/Caddyfile`

---

## Rotate Trojan password

```bash
tp rotate-password
```

This writes `TROJAN_PASSWORD=...` into `/etc/trojan-pro/env`.

To take effect, restart the Trojan service:

```bash
sudo systemctl restart trojan-pro.service
```

---

## Reconfigure DNS provider

```bash
tp reconfigure-dns-provider gcloud
```

- validates required provider env keys first
- mutates manifest fields:
  - `dns_provider`
  - `dns_provider_module`
  - `support_tier`

To take effect, re-render Caddy config and restart Caddy.

---

## Web mode

```bash
tp set-web-mode static
```

```bash
tp set-web-mode upstream --upstream https://origin.example.com
```

This currently updates `install-manifest.json` only.

---

## Export a client bundle

```bash
tp export-client-bundle \
  --direct scripts/tests/fixtures/clash_rules_direct.sample.txt \
  --proxy scripts/tests/fixtures/clash_rules_proxy.sample.txt \
  --reject scripts/tests/fixtures/clash_rules_reject.sample.txt \
  --output dist/client-import/managed-edge.json
```

It derives the profile from the manifest:
- `serverHost` and `sni` from `edge_domain`
- port from `bundle_server_port` (default 443)
- profile name from `bundle_profile_name` (default `Managed Edge`)

---

## Staged runs with `--root-prefix`

For fixture tests or staged validation:

```bash
tp --root-prefix /tmp/trojan-pro-root status --json
```

If you have not installed `tp` yet, run the CLI entry directly from the repo:

```bash
python3 scripts/install/runtime/cli.py --root-prefix /tmp/trojan-pro-root status --json
```
