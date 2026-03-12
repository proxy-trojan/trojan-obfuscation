# Branching & Release Status / 分支与发布状态

## Snapshot / 当前快照

**EN**
- As of **2026-03-12**, the validated delivery baseline is the branch promoted from `feature_1.0_no_obfus_and_no_rules`.
- GitHub Actions **Build and Release** has been verified to produce multi-platform core artifacts and multi-platform desktop client artifacts in one run.
- Verified successful run: **22989454950**.

**中文**
- 截至 **2026-03-12**，当前已验证的稳定交付基线来自 `feature_1.0_no_obfus_and_no_rules` 提升后的主线。
- GitHub Actions 的 **Build and Release** 已验证可在一次运行中产出 **core 多平台编译产物** 与 **桌面 client 多平台分发产物**。
- 已验证成功的运行：**22989454950**。

---

## Branch Strategy / 分支策略

**EN**
- `main`: stable and releasable baseline.
- `develop`: ongoing integration branch for the next round of development.
- `feature/*`: short-lived feature branches created from `develop`, then merged/rebased back into `develop`.
- Promote to `main` only after CI + artifact validation is green.

**中文**
- `main`：稳定、可交付、可发布的主线。
- `develop`：后续持续开发和集成的开发分支。
- `feature/*`：从 `develop` 拉出的短生命周期功能分支，完成后回并到 `develop`。
- 只有在 CI 和产物验证全绿后，才提升到 `main`。

### Suggested daily flow / 建议日常流程

```bash
# 1) start from develop
# 1）从 develop 开始

git checkout develop
git pull --ff-only

git checkout -b feature/<topic>

# 2) develop on feature branch
# 2）在功能分支开发

# ... edit / test / commit ...

# 3) sync back into develop
# 3）回并到 develop

git checkout develop
git merge --ff-only feature/<topic>

# 4) promote to main after validation
# 4）验证通过后再提升到 main
```

---

## Verified Build Outputs / 已验证构建产物

### Core artifacts / Core 编译产物

**EN**
- Linux x86_64
- Linux aarch64
- macOS x86_64
- macOS arm64
- Windows x86_64

**中文**
- Linux x86_64
- Linux aarch64
- macOS x86_64
- macOS arm64
- Windows x86_64

### Client artifacts / Client 分发产物

**EN**
- Linux `.deb`
- Linux release-bundle `.tar.gz`
- Windows `.zip`
- macOS `.app.zip`
- Android `.apk` remains an optional lane and is disabled by default in manual dispatch.

**中文**
- Linux `.deb`
- Linux release-bundle `.tar.gz`
- Windows `.zip`
- macOS `.app.zip`
- Android `.apk` 仍是可选通道，默认手动触发时关闭。

### Validation coverage / 验证覆盖

**EN**
- artifact download and checksum verification
- expected artifact presence checks
- package sanity checks for `.deb`, Windows zip, and macOS app zip

**中文**
- artifact 下载与 checksum 校验
- 预期产物存在性检查
- `.deb`、Windows zip、macOS app zip 的基础结构 sanity 检查

---

## Workflow Entry / 工作流入口

**EN**
- Workflow file: `.github/workflows/release.yml`
- Reusable client packaging workflow: `.github/workflows/client-packaging.yml`
- Manual trigger: GitHub Actions → **Build and Release**

**中文**
- 主 workflow 文件：`.github/workflows/release.yml`
- 可复用 client packaging workflow：`.github/workflows/client-packaging.yml`
- 手动触发入口：GitHub Actions → **Build and Release**

---

## Operational Notes / 操作说明

**EN**
- The previous legacy `main` should be treated as obsolete baseline history, not the active delivery line.
- Keep a backup/archive branch before force-updating `main` so rollback remains possible.
- The validated stable line should remain boring: make risky work happen on `develop` / `feature/*`, not directly on `main`.

**中文**
- 旧的 `main` 应视为过时的历史基线，而不是当前交付主线。
- 在强推更新 `main` 前保留一个 archive/backup 分支，避免回滚时无路可退。
- 稳定主线要尽量“无聊”：高风险改动放在 `develop` / `feature/*` 上，不要直接堆到 `main`。
