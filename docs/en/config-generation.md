# Config generation

This page explains how to convert clash-rules snapshots into an importable client bundle, and how the installer reuses the same path for manifest-backed export.

## Config generation command

```bash
python3 scripts/config/generate-client-bundle.py \
  --direct scripts/tests/fixtures/clash_rules_direct.sample.txt \
  --proxy scripts/tests/fixtures/clash_rules_proxy.sample.txt \
  --reject scripts/tests/fixtures/clash_rules_reject.sample.txt \
  --output dist/client-import/trojan-pro-client-profile-sample.json
```

The artifact is written under `dist/client-import/`.

## Output shape

The generated bundle includes:
- `kind=trojan-pro-client-profile`
- `version=2`
- `routing.policyGroups`
- `routing.rules`

## Client import

- Open the client import UI
- Choose the generated JSON artifact
- Verify policy groups and rules are present
- Replace placeholder server values with production values

## Manifest-backed export

When a host is already installed through the full installer, reuse:

```bash
tp export-client-bundle \
  --direct scripts/tests/fixtures/clash_rules_direct.sample.txt \
  --proxy scripts/tests/fixtures/clash_rules_proxy.sample.txt \
  --reject scripts/tests/fixtures/clash_rules_reject.sample.txt \
  --output dist/client-import/managed-edge.json
```

This path derives `serverHost`, `serverPort`, `sni`, and profile naming from `install-manifest.json`.

## ACME / DNS / 80 / 443 reminder

This page focuses on **config generation**, but the imported profile is only useful if the server installation is healthy:
- **DNS** must be correct
- **ACME** must be able to issue certificates
- Ports **80** / **443** must be reachable

## Rule update

The current model is not a live subscription. It is a regenerate-and-reimport workflow:

1. refresh direct/proxy/reject rule snapshots
2. run config generation again
3. publish the updated JSON
4. have clients re-import the latest bundle

A CI or cron based **rule update** pipeline is the recommended approach.
