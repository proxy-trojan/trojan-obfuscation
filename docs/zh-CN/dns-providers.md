# DNS Providers

当前 full installer 把 DNS provider 视为 manifest 驱动的 registry 条目。

## 当前 full support provider

- `cloudflare`
- `route53`
- `alidns`
- `dnspod`
- `gcloud`

每个 provider 条目包含：
- `support_tier`
- `caddy_dns_module`
- required env keys
- optional env keys

## 运维说明

- 若缺少 provider 必需环境变量，preflight 会 fail-closed。
- `tp reconfigure-dns-provider <provider>` 会先校验 env，再修改 manifest。
- provider registry 真相源位于：`scripts/install/providers/dns-providers.json`
