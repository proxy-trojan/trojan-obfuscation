# 配置生成 / Config generation

本页说明如何把 clash-rules 快照转换为客户端可导入 bundle，以及 full installer 如何复用同一路径做 manifest-backed export。

## 配置生成命令 / config generation

```bash
python3 scripts/config/generate-client-bundle.py \
  --direct scripts/tests/fixtures/clash_rules_direct.sample.txt \
  --proxy scripts/tests/fixtures/clash_rules_proxy.sample.txt \
  --reject scripts/tests/fixtures/clash_rules_reject.sample.txt \
  --output dist/client-import/trojan-pro-client-profile-sample.json
```

输出文件位于 `dist/client-import/`。

## 输出内容

生成结果包含：
- `kind=trojan-pro-client-profile`
- `version=2`
- `routing.policyGroups`
- `routing.rules`

## 客户端导入 / client import

- 打开客户端导入页面
- 选择生成的 JSON 文件
- 校验 policy groups 与 rules 已出现
- 根据生产环境补齐服务器地址、SNI、密码

## Manifest-backed export

当主机已经通过 full installer 安装完成后，可直接复用：

```bash
tp export-client-bundle \
  --direct scripts/tests/fixtures/clash_rules_direct.sample.txt \
  --proxy scripts/tests/fixtures/clash_rules_proxy.sample.txt \
  --reject scripts/tests/fixtures/clash_rules_reject.sample.txt \
  --output dist/client-import/managed-edge.json
```

这条路径会从 `install-manifest.json` 推导 `serverHost`、`serverPort`、`sni` 和 profile 名称。

## ACME / DNS / 80 / 443 关联提醒

虽然本页聚焦 **config generation**，但真实可用仍依赖服务端安装成功：
- 域名 **DNS** 正确
- **ACME** 可签发
- **80** / **443** 可达

## 规则更新 / rule update

当前模型不是在线订阅，而是离线重生成：

1. 定时拉取或更新 direct/proxy/reject 文本规则
2. 重新执行 config generation
3. 将新的 JSON 发给客户端
4. 客户端重新导入最新 bundle

推荐把这个流程放进 cron 或 CI，形成稳定的 **rule update** 机制。
