# Full Installer v1 — Installation & first deployment (Linux)

This guide covers the **end-to-end install flow** for Full Installer v1:

1. prepare DNS + ports
2. provide DNS provider credentials (DNS-01)
3. run `install-kernel.sh` in `--check-only`
4. run `--apply`
5. validate with `tp`
6. export a manifest-backed client bundle

> Note on current posture
>
> Full Installer v1 is **manifest-backed** and has good contract coverage, but some host-mutating parts (package installation / service units / live cert export) may still require operator glue depending on your environment. Treat this as **staging / controlled rollout** unless you have verified your host requirements.

---

## 0. Concepts

### Single source of truth

- `/etc/trojan-pro/install-manifest.json`

Rendered outputs are derived from it:

- `/etc/trojan-pro/config.json` (Trojan runtime config)
- `/etc/caddy/Caddyfile` (Caddy front door config)
- `/etc/trojan-pro/certs/current/*` (stable cert export paths for Trojan)

### Sensitive env

- `/etc/trojan-pro/env`

This is where DNS provider credentials and `TROJAN_PASSWORD` live.

---

## 1. Prerequisites

- A Linux host (systemd assumed)
- DNS records:
  - `www.<domain>` → public web surface
  - `edge.<domain>` → Trojan SNI / front door
- Ports **80** and **443** reachable (both host firewall and provider edge)
- DNS provider API credentials for **DNS-01**

Supported full-tier providers:
- `cloudflare`
- `route53`
- `alidns`
- `dnspod`
- `gcloud`

---

## 2. Provide DNS provider credentials

The installer reads provider credentials from:

1) `/etc/trojan-pro/env` (recommended for day-2)
2) current process environment variables

### Example: Cloudflare

```bash
export CLOUDFLARE_API_TOKEN="..."
```

### Example: Route53

```bash
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_REGION="ap-southeast-1"
# optional
export AWS_SESSION_TOKEN="..."
```

---

## 3. Preflight (check-only)

Run:

```bash
bash scripts/install/install-kernel.sh \
  --www-domain www.example.com \
  --edge-domain edge.example.com \
  --dns-provider cloudflare \
  --check-only
```

Expected:
- prints `phase=preflight`, `phase=detect-os`, `phase=install-deps`
- fails **closed** if required provider env is missing

---

## 4. Apply

Run:

```bash
sudo bash scripts/install/install-kernel.sh \
  --www-domain www.example.com \
  --edge-domain edge.example.com \
  --dns-provider cloudflare \
  --apply
```

Outputs written under `/` by default:

- `/etc/trojan-pro/install-manifest.json`
- `/etc/trojan-pro/config.json`
- `/etc/caddy/Caddyfile`
- `/etc/trojan-pro/certs/current/edge.crt`
- `/etc/trojan-pro/certs/current/edge.key`
- `/usr/local/bin/tp`
- `/usr/local/bin/tpctl` (symlink)

### Staged apply with a root prefix

For a staged run (no writes to `/`), set a root prefix:

```bash
export INSTALL_ROOT_PREFIX=/tmp/trojan-pro-root
sudo -E bash scripts/install/install-kernel.sh \
  --www-domain www.example.com \
  --edge-domain edge.example.com \
  --dns-provider cloudflare \
  --apply
```

---

## 5. Validate

After apply:

```bash
tp status --json
tp validate
```

`tp validate` checks presence of:
- install manifest
- Trojan config
- Caddyfile

---

## 6. Export a manifest-backed client bundle

```bash
tp export-client-bundle \
  --direct scripts/tests/fixtures/clash_rules_direct.sample.txt \
  --proxy scripts/tests/fixtures/clash_rules_proxy.sample.txt \
  --reject scripts/tests/fixtures/clash_rules_reject.sample.txt \
  --output dist/client-import/managed-edge.json
```

This derives:
- `serverHost` / `sni` from `edge_domain`
- server port from `bundle_server_port` (defaults to 443)

---

## Troubleshooting

### missing_provider_env=...

Provider env is missing for the selected `--dns-provider`. Either:
- export the required keys in your shell, or
- put them in `/etc/trojan-pro/env`

See: `docs/en/dns-providers.md`

### validate fails / rollback triggered

The installer applies a last-known-good backup seam for:
- manifest
- Trojan config
- Caddyfile

If validate fails, backups are restored and the installer exits non-zero.
