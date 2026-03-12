# Changelog

All notable changes to this project will be documented in this file.

---

## [Unreleased]

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
