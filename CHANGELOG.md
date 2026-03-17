# Changelog

All notable changes to this project will be documented in this file.

---

## [Unreleased]

### EN

#### Added
- One-click deployment script upgraded to **v3.0** (`deploy_caddy_trojan.sh`):
  - IP certificate support via Let's Encrypt short-lived certificates (6-day validity, auto-renewal).
  - Multi-CA fallback (Let's Encrypt → Buypass → ZeroSSL) for domain certificates.
  - ACME notification hooks: Telegram, DingTalk, Feishu, Slack, Bark, ServerChan, Mailgun, SendGrid.
  - Pre-compiled binary download mode (fast install without compilation).
  - Client config generation: basic, obfuscation, and Clash formats with Trojan URL.
  - Multi-user/password management, backup/restore, and core update functionality.
  - BBR congestion control auto-enable.
  - Health check and comprehensive status reporting.
  - Full CLI argument support for non-interactive automation.
- E2E deployment test (`e2e-deploy-test.sh`):
  - Self-signed certificate with dynamic port allocation.
  - SOCKS5 proxy connectivity, fallback behavior, wrong-password rejection, and concurrent connection stability tests.
  - Registered in CMake CTest as `LinuxSmokeTest-e2e-deploy`.
- Removed legacy `scripts/deploy.sh` (superseded by `deploy_caddy_trojan.sh` v3.0).

### 中文

#### 新增
- 一键部署脚本升级至 **v3.0**（`deploy_caddy_trojan.sh`）：
  - 支持 IP 证书（Let's Encrypt 短期证书，6 天有效期，自动续期）。
  - 域名证书多 CA 自动降级（Let's Encrypt → Buypass → ZeroSSL）。
  - ACME 通知钩子：Telegram、钉钉、飞书、Slack、Bark、Server酱、Mailgun、SendGrid。
  - 预编译二进制下载模式（快速安装，免编译）。
  - 客户端配置自动生成：基础、混淆、Clash 格式及 Trojan URL。
  - 多用户/密码管理、备份恢复、核心更新功能。
  - BBR 拥塞控制自动启用。
  - 健康检查与全面状态报告。
  - 完整 CLI 参数支持，适用于非交互式自动化部署。
- E2E 部署测试（`e2e-deploy-test.sh`）：
  - 自签证书 + 动态端口分配的全链路测试。
  - 覆盖 SOCKS5 代理连通性、Fallback 行为、错误密码拒绝、并发连接稳定性。
  - 已注册到 CMake CTest（`LinuxSmokeTest-e2e-deploy`）。
- 移除旧版 `scripts/deploy.sh`（已被 `deploy_caddy_trojan.sh` v3.0 替代）。

---

## [v1.3.0-beta.2] - 2026-03-17

### EN

#### Fixed
- Release workflow now checks out repository code before artifact validation, so checksum and package validation helper scripts are available in `validate-artifacts`.
- `v1.3.0-beta.1` failed at CI validation due to workflow orchestration, not product build/package failure.

### 中文

#### 修复
- release workflow 的 `validate-artifacts` 现已补上仓库 checkout，确保 checksum 与 package validation 脚本在校验阶段可用。
- `v1.3.0-beta.1` 的失败根因是 CI 编排问题，而不是产品代码/打包产物失败。

---

## [v1.3.0-beta.1] - 2026-03-17

### EN

#### Added
- Desktop lifecycle visibility polish across Settings + Dashboard:
  - explicit close/minimize/quit semantics
  - duplicate-launch posture and external-activation visibility
  - recent activation card with dismiss + age-out + settings deep-link
- App-level runtime error capture/persistence for support workflows.
- Diagnostics export guidance improvements (categorized export failure hints).
- New staging/handoff release docs for desktop beta readiness.

#### Changed
- ProfileStore persistence now supports test-friendly debounce control and pending-save flushing to avoid flaky timer-driven tests.
- Settings form fields migrated to non-deprecated form API usage.

#### Notes
- Linux packaging/build remains green, but tray behavior may fall back to no-op when appindicator is unavailable.
- This tag is a **beta pre-release** intended for staging/small-beta validation.

### 中文

#### 新增
- 桌面生命周期可见性增强（Settings + Dashboard）：
  - close/minimize/quit 语义显式化
  - duplicate-launch 姿态与 external activation 可见化
  - recent activation 卡片（支持 dismiss / age-out / 跳转设置）
- 应用级运行时异常捕获与持久化，提升支持链路可诊断性。
- diagnostics 导出失败的分类化指引。
- 新增桌面 beta 的 handoff / staging release 文档。

#### 变更
- ProfileStore 持久化支持测试态 debounce 控制与 pending-save flush，降低 timer 相关测试不稳定。
- Settings 表单迁移至非废弃 API 用法。

#### 备注
- Linux 打包与构建可通过；若缺少 appindicator，tray 行为可能降级为 no-op fallback。
- 该 tag 为 **beta 预发布**，用于 staging / 小范围验证。

---

## [v1.1.1] - 2026-03-12

### EN
- Align client package version naming to stable release style (`1.1.0` / `1.1.0-1`).
- Upgrade core workflow actions to latest major versions (checkout/upload/download/setup-java).
- Make release notes client artifact names pattern-based to avoid stale hardcoded names.
- Disable Flutter action cache integration in client packaging jobs to avoid Node 20 deprecation noise from transitive `actions/cache@v4`.

### 中文
- 将 client 打包版本命名对齐为稳定版风格（`1.1.0` / `1.1.0-1`）。
- 升级核心 workflow action 到最新主版本（checkout/upload/download/setup-java）。
- 将 release notes 中的 client 产物命名改为模式匹配，避免硬编码过期。
- 在 client packaging 作业中关闭 Flutter action 缓存集成，避免由传递依赖 `actions/cache@v4` 带来的 Node 20 弃用告警。

---

## [v1.1.0] - 2026-03-12

### EN

#### Added
- Unified GitHub Actions **Build and Release** pipeline for:
  - core artifacts: Linux x86_64/aarch64, macOS x86_64/arm64, Windows x86_64
  - client artifacts: Linux `.deb` + `.tar.gz`, Windows `.zip`, macOS `.app.zip`, Android `.apk`
- Artifact checksum generation and verification (`.sha256`) for both core and client deliverables.
- Artifact validation stage with package sanity checks before release publication.
- Bilingual branch/release status documentation.

#### Changed
- Promoted the validated stable baseline to `main`.
- Established `develop` as the ongoing integration branch for future work.
- Hardened macOS x86_64 build lane with x86_64 OpenSSL linkage on macOS runners.

### 中文

#### 新增
- 统一的 GitHub Actions **Build and Release** 流程，可同时产出：
  - core 产物：Linux x86_64/aarch64、macOS x86_64/arm64、Windows x86_64
  - client 产物：Linux `.deb` + `.tar.gz`、Windows `.zip`、macOS `.app.zip`、Android `.apk`
- 为 core 与 client 产物补齐 `.sha256` 生成与校验。
- 在 release 发布前新增 artifact 验证阶段与包体结构 sanity 检查。
- 新增中英双文分支/发布状态文档。

#### 变更
- 将已验证稳定基线提升为 `main`。
- 将 `develop` 设为后续持续开发的集成分支。
- 强化 macOS x86_64 构建链路，确保在 macOS runner 上链接到 x86_64 OpenSSL。

---

## [v1.0.4] - historical
- Legacy release tag preserved for historical compatibility.

## [v1.0.3] - historical
- Legacy release tag preserved for historical compatibility.

## [v1.0.2] - historical
- Legacy release tag preserved for historical compatibility.
