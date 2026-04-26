# DNS providers

The full installer currently treats DNS providers as manifest-backed registry entries.

## Full support providers

- `cloudflare`
- `route53`
- `alidns`
- `dnspod`
- `gcloud`

Each provider entry includes:
- `support_tier`
- `caddy_dns_module`
- required env keys
- optional env keys

## Operational notes

- Preflight fails closed when required provider env is missing.
- `tp reconfigure-dns-provider <provider>` validates env before mutating the manifest.
- Provider registry source of truth: `scripts/install/providers/dns-providers.json`
