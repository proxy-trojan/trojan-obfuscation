# 快速安装（引导式）— Linux

本页给出“**引导式 quick install**”的最短路径，用于在 Linux 主机上安装一套自托管 TLS 服务栈。

- 入口：**一行命令**（`curl | sudo bash`）
- 供应链安全：从 **GitHub Releases（latest）** 下载 `tp`，并校验 **sha256**
- 引导安装：运行 `tp install`（交互式），在真正修改主机前必须输入 `YES`

> 中性定位说明
>
> 本指南只覆盖基础设施安装与运维（ACME DNS-01、systemd），不讨论任何特定的网络规避用途。

---

## 1）前置条件

- 一台 Linux 主机（默认假设 systemd）
- 已准备好域名与 DNS 记录：
  - `www.<domain>`（web surface）
  - `edge.<domain>`（TLS 入口域名）
- 端口 **80** / **443** 可达（系统防火墙 + 云侧安全组都要放行）
- DNS provider 的 API 凭据（用于 **ACME DNS-01**）

当前 full-tier DNS provider：

- `cloudflare`
- `route53`
- `alidns`
- `dnspod`
- `gcloud`

---

## 2）一行命令（引导式）

执行：

```bash
curl -fsSL https://github.com/proxy-trojan/trojan-obfuscation/releases/latest/download/tp-install.sh | sudo bash
```

它会做什么：

1. 按你的 CPU 架构下载 `tp`，并校验对应的 `.sha256`。
2. 将 `tp` 安装到 `/usr/local/bin/tp`。
3. 启动交互式引导：`tp install`。

---

## 3）你会被询问哪些信息

引导安装会询问：

- `www domain`
- `edge domain`
- `dns provider`

并检查所选 provider 的必需环境变量。

> 凭据读取来源：`/etc/trojan-pro/env` + 当前进程环境变量。

---

## 4）Plan + 确认门禁（必需）

在真正修改主机之前，installer 会打印一段 plan，包括：

- 将要写入/更新的文件路径（主要在 `/etc`）
- 可能被重启的服务
- 回滚说明（last-known-good 备份）

你必须输入 **`YES`** 才会继续执行。输入其他内容会直接退出。

---

## 5）安装后验证

apply 完成后执行：

```bash
tp status --json
tp validate
```

---

## 6）常见问题排查

### missing_provider_env=...

说明所选 DNS provider 的必需环境变量缺失。

修复方式：

- 在当前 shell `export` 对应环境变量，或
- 写入 `/etc/trojan-pro/env`（推荐，便于 day-2 运维）

参考：
- `docs/zh-CN/dns-providers.md`

### ACME 失败 / 证书未签发

常见原因：

- DNS 解析尚未生效（传播未完成）
- 80/443 未放行
- 主机上已有服务占用 80/443

请先确认 DNS 与端口条件，再重新执行安装。

### 因未输入 YES 而中止

这是预期行为。重新执行一行命令，并在确认无误后输入 `YES`。
