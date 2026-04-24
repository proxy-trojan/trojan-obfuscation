# Install kernel

`scripts/install/install-kernel.sh` is the generic Linux installer entry skeleton. It owns argument parsing and phase orchestration.

## Supported install command

```bash
bash scripts/install/install-kernel.sh \
  --domain example.com \
  --email ops@example.com \
  --password 'change-this-password' \
  --check-only
```

Apply mode currently fails closed. Until real install logic lands, use `--check-only` only.

## Phase layout

- detect-os
- install-deps
- install-core
- configure-caddy
- write-runtime-config

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
