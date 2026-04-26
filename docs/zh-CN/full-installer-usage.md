# Full Installer v1 — 安装与首次部署（Linux）

本指南覆盖 Full Installer v1 的端到端安装路径：

1. 准备 DNS 与端口
2. 提供 DNS provider 凭据（DNS-01）
3. 先跑 `install-kernel.sh --check-only`
4. 再跑 `--apply`
5. 用 `tp` 做验证
6. 导出 manifest-backed client bundle

> 当前姿态说明
>
> Full Installer v1 已实现 **manifest 驱动** 与较完整的 contract 测试闭环，但部分 host-mutating 细节（依赖安装 / systemd unit 落盘 / live cert export）在不同环境下可能仍需要 operator glue。请先在 **staging/可控环境** 验证再扩大使用。

---

## 0. 核心概念

### 单一真相源

- `/etc/trojan-pro/install-manifest.json`

其派生出的渲染产物包括：

- `/etc/trojan-pro/config.json`（Trojan runtime config）
- `/etc/caddy/Caddyfile`（Caddy 前门配置）
- `/etc/trojan-pro/certs/current/*`（Trojan 稳定 cert export 路径）

### 敏感环境变量

- `/etc/trojan-pro/env`

DNS provider 凭据与 `TROJAN_PASSWORD` 等敏感值应写在这里。

---

## 1. 前置条件

- Linux 主机（默认假设 systemd）
- 域名解析：
  - `www.<domain>` → web surface
  - `edge.<domain>` → Trojan SNI / front door
- 端口 **80** / **443** 可达（系统防火墙 + 云侧安全组都要放行）
- DNS provider API 凭据（DNS-01）

当前 full-tier provider：
- `cloudflare`
- `route53`
- `alidns`
- `dnspod`
- `gcloud`

---

## 2. 提供 DNS provider 凭据

installer 会从以下两处读取 provider 凭据：

1) `/etc/trojan-pro/env`（推荐，便于 day-2 使用）
2) 当前进程环境变量

### 示例：Cloudflare

```bash
export CLOUDFLARE_API_TOKEN="..."
```

### 示例：Route53

```bash
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_REGION="ap-southeast-1"
# optional
export AWS_SESSION_TOKEN="..."
```

---

## 3. Preflight（check-only）

先跑：

```bash
bash scripts/install/install-kernel.sh \
  --www-domain www.example.com \
  --edge-domain edge.example.com \
  --dns-provider cloudflare \
  --check-only
```

预期：
- 输出 `phase=preflight` / `phase=detect-os` / `phase=install-deps`
- 若缺 provider env，会 fail-closed 并打印 `missing_provider_env=...`

---

## 4. Apply

执行真实安装：

```bash
sudo bash scripts/install/install-kernel.sh \
  --www-domain www.example.com \
  --edge-domain edge.example.com \
  --dns-provider cloudflare \
  --apply
```

默认写入路径（root prefix 为 `/`）：

- `/etc/trojan-pro/install-manifest.json`
- `/etc/trojan-pro/config.json`
- `/etc/caddy/Caddyfile`
- `/etc/trojan-pro/certs/current/edge.crt`
- `/etc/trojan-pro/certs/current/edge.key`
- `/usr/local/bin/tp`
- `/usr/local/bin/tpctl`（symlink）

### 用 root prefix 做 staged apply

如果想把产物写到临时目录（不写入 `/`），可设置 root prefix：

```bash
export INSTALL_ROOT_PREFIX=/tmp/trojan-pro-root
sudo -E bash scripts/install/install-kernel.sh \
  --www-domain www.example.com \
  --edge-domain edge.example.com \
  --dns-provider cloudflare \
  --apply
```

---

## 5. 验证

安装完成后：

```bash
tp status --json
tp validate
```

`tp validate` 会检查以下文件是否存在：
- install manifest
- Trojan config
- Caddyfile

---

## 6. 导出 manifest-backed client bundle

```bash
tp export-client-bundle \
  --direct scripts/tests/fixtures/clash_rules_direct.sample.txt \
  --proxy scripts/tests/fixtures/clash_rules_proxy.sample.txt \
  --reject scripts/tests/fixtures/clash_rules_reject.sample.txt \
  --output dist/client-import/managed-edge.json
```

这条路径会从 manifest 推导：
- `serverHost` / `sni` = `edge_domain`
- 端口 = `bundle_server_port`（默认 443）

---

## 常见问题排查

### missing_provider_env=...

说明所选 `--dns-provider` 的必需 env 缺失。你可以：
- 在 shell 中 export 对应 env，或
- 写入 `/etc/trojan-pro/env`

参考：`docs/zh-CN/dns-providers.md`

### validate 失败 / rollback 触发

installer 对以下文件有 last-known-good 备份 seam：
- manifest
- Trojan config
- Caddyfile

validate 失败时会恢复备份并以非 0 退出。
