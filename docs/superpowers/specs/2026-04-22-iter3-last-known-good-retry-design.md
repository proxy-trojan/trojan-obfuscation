# Iter-3: Profiles 高频动作条的 last-known-good retry 设计规格（Option 1 + Semantics A）

- 日期：2026-04-22
- 关联 issue：#51（High-frequency actions stability & truthful quick-path closure）
- 目标：在 Profiles 页 `HighFrequencyActionsStrip` 增加 **Quick Retry (Last Good)** 入口，且在 runtime-truth / readiness / action-safety 约束下 **稳定、可解释、不可误导**。

---

## 1. 背景

Iter-3 的 daily-use 口径要求：高频动作必须 deterministic，且 UI 文案不得在 runtime/session truth 未确认前宣称成功。

当前现状：
- Profiles 页已存在 `HighFrequencyActionsStrip`（Quick Connect/Disconnect/Switch）。
- Controller 边界 `AdapterBackedClientController` 内已有 `_lastKnownGoodProfileId`：当 routing mini smoke 成功后写入，并持久化到 routing safety state。
- 但 UI 尚未暴露一个显式的“回到上次成功配置”快捷入口。

---

## 2. 设计目标（What good looks like）

1) **入口位置固定**：按钮在 Profiles 页的高频动作条（HF strip）出现。
2) **语义清晰且不漂移**：用户点击后，UI 与连接目标一致（不出现“看着 A 详情连着 B”的漂移）。
3) **不绕过门禁**：readiness preflight / runtime truth / action-safety gating 均必须执行。
4) **反馈 truthful**：不在 session truth 未确认前宣称已连接成功。
5) **可测证据**：补齐/扩展 widget test，形成可复现的 gate evidence。

---

## 3. 方案对比（Decision record）

### 方案 1（采用）：UI 驱动 + controller 只读暴露 `lastKnownGoodProfileId`
- `ClientControllerApi` 增加只读 getter：`String? get lastKnownGoodProfileId`
- `AdapterBackedClientController` override 返回 `_lastKnownGoodProfileId`
- Profiles UI 通过 profileStore 查找对应 profile，并按 gating 执行 retry

**理由**：边界清晰、改动小、controller 不依赖 profileStore，可测性强。

### 方案 2：controller 提供 `connectLastKnownGood()`
**不采用**：会迫使 controller 了解 profileStore/secret，边界污染。

### 方案 3：lastKnownGood 迁移到 profileStore
**不采用**：与 routing safety state 重复，容易口径漂移。

---

## 4. 点击语义（User-confirmed Semantics A）

用户确认采用 **A**：

> 点击 `Quick Retry (Last Good)` 后：
> 1) 先将 selected profile 切换到 last-known-good
> 2) 对 last-known-good profile 跑 readiness preflight
> 3) allowed 才执行 connect(last-known-good)

### 为什么必须先切 selected
- 避免“Profile details 显示 A，但实际连接 B”的语义漂移。
- 与 Profiles 页现有状态展示与 gating 逻辑保持一致。

---

## 5. UI/可见性规则

### 5.1 按钮渲染条件（建议）
按钮 `Quick Retry (Last Good)` 出现需满足：
- `services.controller.lastKnownGoodProfileId != null`
- profileStore 可找到对应 profile
- `lastKnownGoodProfileId != selected.id`

### 5.2 按钮启用条件（门禁）
- 继续服从 HF strip 现有 `enabled: connectionPolicy.canToggleConnection`
- 额外建议：当 `status.phase == connected` 时，quick retry handler 为 `null`（不提供“连着时重试”的歧义路径）

---

## 6. Readiness preflight 复用（避免绕过）

将 `_runConnectReadinessPreflight()` 扩展为支持 `profileOverride`：
- 默认使用当前 `selected`
- quick retry 传入 `profileOverride: lastGoodProfile`

blocked 反馈保持一致（复用既有 copy 结构）：
- `Connect blocked: <summary> Next action: <label>`

---

## 7. 反馈文案（truth-safe）

快速重试路径完成后：
- 使用 `buildRuntimeActionFeedback(action: RuntimeActionKind.retry, ...)`
- 不自行拼“Connected!” 之类文案，避免与 runtime truth 冲突。

---

## 8. 需要修改/新增的文件

- `client/lib/features/controller/application/client_controller_api.dart`
- `client/lib/features/controller/application/adapter_backed_client_controller.dart`
- `client/lib/features/profiles/presentation/high_frequency_actions_strip.dart`
- `client/lib/features/profiles/presentation/profiles_page.dart`
- `client/test/features/profiles/presentation/high_frequency_actions_strip_test.dart`
- `client/test/features/profiles/presentation/profiles_page_action_gating_test.dart`

---

## 9. 验证（Evidence commands）

满足 issue #51 证据要求：
- `flutter test test/features/profiles/presentation/high_frequency_actions_strip_test.dart`
- `flutter test test/features/profiles/presentation/profiles_page_action_gating_test.dart`

---

## 10. Non-goals（本次不做）

- 不新增 controller 写路径或改变 `_lastKnownGoodProfileId` 写入策略。
- 不改变 Iter-3 既有 runtime truth 判定口径。
- 不新增 telemetry 事件（可后续按指标口径再补）。
