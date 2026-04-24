# 安装骨架说明 / Install kernel

`scripts/install/install-kernel.sh` 是通用 Linux 安装入口骨架，负责参数解析与 phase 编排。

## 支持的 install command

```bash
bash scripts/install/install-kernel.sh \
  --domain example.com \
  --email ops@example.com \
  --password 'change-this-password' \
  --check-only
```

当前 apply 模式为 fail-closed；在真实安装细节实现之前，请只使用 `--check-only`。

## Phase 结构

- detect-os
- install-deps
- install-core
- configure-caddy
- write-runtime-config

## ACME / DNS / 80 / 443

- **ACME** 证书申请前，先确认 **DNS** 已解析到目标主机
- 确认系统和云防火墙同时放行 **80** / **443**
- 若 80/443 被其他进程占用，Caddy 无法接管签发流程
- 变更域名后需要再次检查解析与端口状态

## 客户端导入前的关联步骤 / client import dependency

安装骨架本身不生成客户端路由配置；客户端导入依赖单独的 **config generation**：

```bash
python3 scripts/config/generate-client-bundle.py \
  --direct scripts/tests/fixtures/clash_rules_direct.sample.txt \
  --proxy scripts/tests/fixtures/clash_rules_proxy.sample.txt \
  --reject scripts/tests/fixtures/clash_rules_reject.sample.txt \
  --output dist/client-import/trojan-pro-client-profile-sample.json
```

## 规则更新 / rule update

- 服务端安装与客户端 routing 更新是两条链路
- 规则变化后，需定时重新生成 bundle 并通知客户端重新导入
- 推荐用 cron / CI 做周期性 **rule update**
