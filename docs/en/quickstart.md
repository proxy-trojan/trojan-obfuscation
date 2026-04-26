# Quickstart

This page shows the shortest path: prepare a Linux host and domain, run the **install command**, then generate and import the client routing bundle.

## 1. Prerequisites

- A reachable Linux host
- A domain with **DNS** pointing to the public IP of that host
- An email address for **ACME** registration
- Open **80** / **443** on the firewall and provider network layer

## 2. Install command

Start with `--check-only` to validate preflight and host prerequisites:

```bash
export CLOUDFLARE_API_TOKEN="..."

bash scripts/install/install-kernel.sh \
  --www-domain www.example.com \
  --edge-domain edge.example.com \
  --dns-provider cloudflare \
  --check-only
```

Then run `--apply` to perform the installation:

```bash
bash scripts/install/install-kernel.sh \
  --www-domain www.example.com \
  --edge-domain edge.example.com \
  --dns-provider cloudflare \
  --apply
```

After apply, use `tp` for day-2 checks.

## 3. ACME notes

- **ACME** issuance depends on correct **DNS**
- Port **80** and **443** must be reachable
- Make sure no other service is already binding **80** / **443**
- Wait for DNS propagation before first issuance attempts

## 4. Config generation

Generate an importable client profile from clash-rules snapshots:

```bash
python3 scripts/config/generate-client-bundle.py \
  --direct scripts/tests/fixtures/clash_rules_direct.sample.txt \
  --proxy scripts/tests/fixtures/clash_rules_proxy.sample.txt \
  --reject scripts/tests/fixtures/clash_rules_reject.sample.txt \
  --output dist/client-import/trojan-pro-client-profile-sample.json
```

## 5. Client import

- Open Trojan Pro Client
- Go to the profile import flow
- Select `dist/client-import/*.json`
- Confirm the imported `routing.policyGroups` and `routing.rules`
- Replace placeholder server fields with real production values

## 6. Rule update

The current model uses static bundles, not live subscriptions.

Recommended **rule update** workflow:
- run scheduled config generation in CI or cron
- publish the latest JSON artifact
- ask clients to re-import the refreshed bundle

Related docs:
- [Install kernel](./install-kernel.md)
- [Config generation](./config-generation.md)
- [Branch cleanup runbook](../ops/branch-cleanup.md)
