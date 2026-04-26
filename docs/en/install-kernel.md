# Install kernel

`scripts/install/install-kernel.sh` is the manifest-backed Linux installer entrypoint. It owns argument parsing, preflight, apply orchestration, validation, and rollback seam setup.

## Supported install commands

```bash
bash scripts/install/install-kernel.sh \
  --www-domain www.example.com \
  --edge-domain edge.example.com \
  --dns-provider cloudflare \
  --check-only
```

```bash
bash scripts/install/install-kernel.sh \
  --www-domain www.example.com \
  --edge-domain edge.example.com \
  --dns-provider cloudflare \
  --apply
```

## Phase layout

- preflight
- detect-os
- install-deps
- install-core
- write-runtime-config
- configure-caddy
- cert-bootstrap
- activate-services
- validate

## Rollback / fail-closed

- apply mode keeps last-known-good backups for manifest / Trojan config / Caddyfile
- validate failure restores backed-up files and exits non-zero
- provider env failure stops before host mutation

## ACME / DNS / 80 / 443

- Before **ACME** issuance, confirm **DNS** resolves to the target host
- Open **80** / **443** at both OS firewall and cloud/network edge
- If another service already owns **80** or **443**, Caddy cannot complete issuance
- Re-check DNS and ports after domain or host changes

## Dependency on config generation and client import

The installer kernel does not create the client routing bundle. For **client import**, run **config generation** separately:

```bash
python3 scripts/config/generate-client-bundle.py \
  --direct scripts/tests/fixtures/clash_rules_direct.sample.txt \
  --proxy scripts/tests/fixtures/clash_rules_proxy.sample.txt \
  --reject scripts/tests/fixtures/clash_rules_reject.sample.txt \
  --output dist/client-import/trojan-pro-client-profile-sample.json
```

## Rule update

- Server installation and client routing refresh are separate flows
- After rules change, re-run bundle generation and ask clients to re-import
- A scheduled CI or cron job is the recommended **rule update** mechanism
