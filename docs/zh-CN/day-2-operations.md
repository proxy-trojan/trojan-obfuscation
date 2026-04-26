# Day-2 运维 — `tp` CLI

本指南说明 `tp` 提供的 day-2 管理能力。

- installer `--apply` 会把 `tp` 安装到 `/usr/local/bin/tp`
- `tpctl` 是兼容别名

> 重要提示
>
> 部分 mutation 命令只会更新 **manifest/env**，不会自动重新渲染配置或重启服务；需要 operator 自己执行对应动作。

---

## 状态与验证

```bash
tp status
```

```bash
tp status --json
```

```bash
tp validate
```

`validate` 会检查以下文件是否存在：
- `/etc/trojan-pro/install-manifest.json`
- `/etc/trojan-pro/config.json`
- `/etc/caddy/Caddyfile`

---

## 轮换 Trojan 密码

```bash
tp rotate-password
```

该命令会把 `TROJAN_PASSWORD=...` 写入 `/etc/trojan-pro/env`。

要让新密码生效，需要重启 Trojan 服务：

```bash
sudo systemctl restart trojan-pro.service
```

---

## 切换 DNS provider

```bash
tp reconfigure-dns-provider gcloud
```

行为：
- 先校验 provider 必需 env key 是否齐全
- 再修改 manifest 字段：
  - `dns_provider`
  - `dns_provider_module`
  - `support_tier`

要让变更生效，需要重新渲染 Caddy 配置并重启 Caddy。

---

## Web mode

```bash
tp set-web-mode static
```

```bash
tp set-web-mode upstream --upstream https://origin.example.com
```

当前版本该命令只会更新 `install-manifest.json`。

---

## 导出 client bundle

```bash
tp export-client-bundle \
  --direct scripts/tests/fixtures/clash_rules_direct.sample.txt \
  --proxy scripts/tests/fixtures/clash_rules_proxy.sample.txt \
  --reject scripts/tests/fixtures/clash_rules_reject.sample.txt \
  --output dist/client-import/managed-edge.json
```

它会从 manifest 推导 profile：
- `serverHost` 和 `sni` = `edge_domain`
- 端口 = `bundle_server_port`（默认 443）
- profile 名称 = `bundle_profile_name`（默认 `Managed Edge`）

---

## 使用 `--root-prefix` 做 staged 运行

用于 fixture 测试或 staged 验证：

```bash
tp --root-prefix /tmp/trojan-pro-root status --json
```

如果还没安装 `tp`，可直接用 repo 内入口：

```bash
python3 scripts/install/runtime/cli.py --root-prefix /tmp/trojan-pro-root status --json
```
