# 快速开始 / Quickstart

本页给出最短路径：先准备 Linux 主机与域名，再执行 **install command**，最后生成并导入客户端 routing 配置。

## 1. 前置准备

- 一台可联网的 Linux 主机
- 一个已经解析到该主机公网 IP 的域名
- 可以接收 ACME 邮件的邮箱
- 放行 **80** / **443** 端口

## 2. 安装命令 / install command

当前安装骨架支持检测与计划模式，推荐先执行 `--check-only`：

```bash
bash scripts/install/install-kernel.sh \
  --domain example.com \
  --email ops@example.com \
  --password 'change-this-password' \
  --check-only
```

如果后续任务补齐 apply 实现，再按 runbook 执行真实安装。

## 3. ACME 注意事项 / ACME notes

- **ACME** 签发依赖正确的 **DNS** 解析
- 80/443 端口必须可达，否则 HTTP-01 会失败
- 若主机已有其他 Web 服务，请确认不会抢占 **80** / **443**
- 首次签发前先确认域名已经传播完成

## 4. 配置生成 / config generation

使用 clash-rules 快照生成客户端可导入配置：

```bash
python3 scripts/config/generate-client-bundle.py \
  --direct scripts/tests/fixtures/clash_rules_direct.sample.txt \
  --proxy scripts/tests/fixtures/clash_rules_proxy.sample.txt \
  --reject scripts/tests/fixtures/clash_rules_reject.sample.txt \
  --output dist/client-import/trojan-pro-client-profile-sample.json
```

## 5. 客户端导入 / client import

- 打开 Trojan Pro Client
- 进入 Profile import 页面
- 选择 `dist/client-import/*.json`
- 导入后检查 `routing.policyGroups` 与 `routing.rules`
- 再补上真实服务器地址和密码

## 6. 规则更新 / rule update

当前 routing 是静态快照，不是远程订阅。

建议机制：
- 定时任务或 CI **rule update**：周期性重新运行 config generation
- 将新 JSON 重新分发给客户端
- 客户端重新导入最新 bundle

相关文档：
- [安装骨架说明](./install-kernel.md)
- [配置生成说明](./config-generation.md)
- [分支清理运维说明](../ops/branch-cleanup.md)
