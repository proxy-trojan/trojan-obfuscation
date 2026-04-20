# Iteration 1 Issue Pack — First Connect Path 1.0 (A1)

> 目标：把“从 0 到第一次 runtime-true connect test”做成一条**可复现**且**不误导**的主路径；失败必须落到 failure family + next action（可点击闭环）。

**Milestone（建议）**：`Iter-1: First Connect Path 1.0`

**Release Train 对齐**：全部属于 **硬 Gate**（三平台必须过）。

---

## I1-01 Profiles 一键 Connect Test 主路径（readiness → connect）

**Labels**：`track:client` `area:profiles` `gate:hard` `platform:all`

**Background**
- Profiles 页面需要一条默认主路径，用户不用去 Advanced 里猜。

**Acceptance Criteria**
- [ ] 在 Profiles selected card 上提供明确的主 CTA（Connect test）。
- [ ] readiness 为 `blocked` 时主 CTA 不可触发，并显示 next action（如 Set Password / Open Troubleshooting）。
- [ ] readiness 为 `ready/degraded` 时可触发 connect。
- [ ] 成功口径：仅当 runtime session 达到 **runtime-true session-ready** 才视为成功。

**Test / Evidence**
- [ ] `flutter test test/features/profiles/presentation/profiles_page_action_gating_test.dart`
- [ ] 更新 `docs/desktop-validation-matrix.md` 三平台勾选（附版本号/证据）

**Touched files (expected)**
- `client/lib/features/profiles/presentation/profiles_page.dart`
- `client/lib/features/profiles/presentation/profile_connection_action_policy.dart`

---

## I1-02 Connect Timeline 组件（planned/launching/alive/session-ready）

**Labels**：`track:client` `area:profiles` `area:controller` `gate:hard` `platform:all`

**Background**
- 连接中不能黑箱等待；阶段反馈是 A1 的核心体验。

**Acceptance Criteria**
- [ ] connecting 状态可见阶段化反馈（至少 planned/launching/alive/session-ready）。
- [ ] error 状态明确显示 failure family + next action。
- [ ] disconnecting/stopping 状态不宣告“已断开”，直到 evidence 确认。

**Test / Evidence**
- [ ] 新增 timeline widget test（组件级）
- [ ] 回归：`flutter test test/features/profiles/presentation/profiles_page_action_gating_test.dart`

**Touched files (expected)**
- `client/lib/features/profiles/presentation/*`（新增 timeline widget 文件）

---

## I1-03 FailureFamily 映射入口统一（优先结构化字段）

**Labels**：`track:client` `area:controller` `gate:hard` `platform:all`

**Background**
- 不允许 UI 靠 `contains()` 猜测错误；优先使用 errorCode/phase 等结构化字段。

**Acceptance Criteria**
- [ ] `classifyFailureFamily()` 优先使用 `errorCode`（若存在）。
- [ ] phase/summary/detail 仅作为 fallback。
- [ ] 覆盖至少：launch/config/environment/connect/user_input/export_os/unknown。

**Test / Evidence**
- [ ] 新增/补齐 unit tests 覆盖上述用例（目标：高信号，不追求 100% 覆盖率）。

**Touched files (expected)**
- `client/lib/features/controller/domain/failure_family.dart`
- `client/test/**/failure_family*_test.dart`（若需要新增）

---

## I1-04 ClientConnectionStatus failure 字段 lifecycle（清理/重试不残留）

**Labels**：`track:client` `area:controller` `gate:hard` `platform:all`

**Background**
- 失败→重试→成功后，旧 errorCode/failureFamilyHint 不应残留。

**Acceptance Criteria**
- [ ] 成功 connect 后：`errorCode` / `failureFamilyHint` 为空。
- [ ] retry/connect 新发起时：旧 failure 字段被清理。
- [ ] disconnect 后：状态干净。

**Test / Evidence**
- [ ] 扩展 `adapter_backed_client_controller_test.dart` 覆盖：失败→重试→成功/失败→disconnect。

**Touched files (expected)**
- `client/lib/features/controller/application/adapter_backed_client_controller.dart`
- `client/test/features/controller/application/adapter_backed_client_controller_test.dart`

---

## I1-05 Secret storage truth：UI/Export 口径一致（secure vs fallback 明示）

**Labels**：`track:client` `area:profiles` `area:diagnostics` `gate:hard` `platform:all`

**Background**
- “已保存密码”必须讲真话：是否 secure、是否持久化、是否仅会话 fallback。

**Acceptance Criteria**
- [ ] Profiles 明示：secure storage / fallback storage（会话）
- [ ] Diagnostics export 中也明示同一口径
- [ ] 文案不误导用户“已持久安全保存”

**Test / Evidence**
- [ ] `flutter test test/features/diagnostics/application/diagnostics_export_service_test.dart`
- [ ] 如需要，补 widget test 验证 Profiles 显示

**Touched files (expected)**
- `client/lib/features/profiles/presentation/profiles_page.dart`
- `client/lib/features/diagnostics/application/diagnostics_export_service.dart`

---

## I1-06 exportSummary：导出前摘要与导出 payload 字段级一致

**Labels**：`track:client` `area:diagnostics` `gate:hard` `platform:all`

**Background**
- 用户看到的摘要必须与导出 JSON 中的 `exportSummary` 一致，否则支持口径会裂。

**Acceptance Criteria**
- [ ] `exportSummary.runtimePostureLabel/evidenceGrade/runtimeTruth/recoveryHint/usageHint` 与 UI 摘要一致。
- [ ] 摘要内容不重复/不与 runtime truth 文案冲突。

**Test / Evidence**
- [ ] 扩展 `diagnostics_export_service_test.dart` 做字段级断言。
- [ ] `flutter test test/features/diagnostics/presentation/export_summary_sheet_test.dart`

**Touched files (expected)**
- `client/lib/features/diagnostics/presentation/export_summary_sheet.dart`
- `client/lib/features/diagnostics/application/diagnostics_export_service.dart`

---

## I1-07 Next Action Policy（blocked / failure family → 默认下一步动作）

**Labels**：`track:client` `area:profiles` `gate:hard` `platform:all`

**Background**
- A1 目标：失败时 60 秒内知道下一步。

**Acceptance Criteria**
- [ ] blocked/readiness：默认动作清晰（Set Password / Open Settings / Open Troubleshooting）。
- [ ] error family：至少 Top5 family 都有默认动作。
- [ ] 统一入口：不要散落在多个 widget 内部临时判断。

**Test / Evidence**
- [ ] 新增 policy 单测：输入（status + readiness + family）→ 输出（action + label）。

**Touched files (expected)**
- 新增：`client/lib/features/profiles/presentation/next_action_policy.dart`（或等价位置）
- 对应 test 文件

---

## I1-08 所有 Connect 入口都服从 readiness blocked（含 quick actions）

**Labels**：`track:client` `area:profiles` `gate:hard` `platform:all`

**Background**
- 不能出现“主按钮被挡住，但快捷按钮还能硬连”的漏点。

**Acceptance Criteria**
- [ ] 所有 connect 入口（主 CTA / quick connect）都先检查 readiness。
- [ ] blocked 时给出同口径提示 + next action。

**Test / Evidence**
- [ ] 扩展 `profiles_page_action_gating_test.dart` 覆盖 quick connect 被挡住。

**Touched files (expected)**
- `client/lib/features/profiles/presentation/profiles_page.dart`
- `client/lib/features/profiles/presentation/high_frequency_actions_strip.dart`

---

## I1-09 Disconnect/Exit truth：不允许“假断开/假停止”

**Labels**：`track:client` `area:controller` `gate:hard` `platform:all`

**Background**
- 断开/退出的误导会直接摧毁信任。

**Acceptance Criteria**
- [ ] disconnecting/stopping 时 UI 明确提示“等待 exit confirmation”。
- [ ] stop-pending 不可被当作 fully closed。

**Test / Evidence**
- [ ] 扩展 `diagnostics_support_policy_test.dart`/profiles 相关 test 覆盖 stopping truth。

**Touched files (expected)**
- `client/lib/features/controller/domain/controller_runtime_session.dart`
- `client/lib/features/diagnostics/presentation/diagnostics_support_policy.dart`

---

## I1-10 Runbook：First connect（A1 内测）流程文档

**Labels**：`track:docs` `gate:hard` `platform:all`

**Acceptance Criteria**
- [ ] 文档包含：安装→导入→password/secure storage→readiness→connect test→导出 bundle。
- [ ] 明确成功口径：runtime-true session-ready。

**Evidence**
- [ ] 三平台各完成一次手工验证，并在矩阵里记录版本号/证据。

**Touched files (expected)**
- 新增：`docs/runbooks/first-connect-a1.md`

---

## I1-11 桌面验证矩阵升级为 v1.6+ 内测矩阵（可持续打勾）

**Labels**：`track:docs` `gate:hard` `platform:all`

**Acceptance Criteria**
- [ ] 矩阵新增 Iter-1 相关条目（first connect path、next action、bundle export）。
- [ ] Iter-1 完成后，三平台都有记录。

**Touched files (expected)**
- `docs/desktop-validation-matrix.md`

---

## I1-12 固定“关键验证组合”命令（本地/CI 都可复用）

**Labels**：`track:client` `track:core` `gate:hard` `platform:all`

**Acceptance Criteria**
- [ ] 一条命令能跑 analyze + Iter-1 关键 flutter tests + 关键 python tests。
- [ ] 输出可被粘贴到 PR 作为证据。

**Evidence**
- [ ] 在 PR 描述中贴出该命令的最新输出摘要。

**Touched files (expected)**
- 新增：`scripts/validate_iter1_first_connect.sh`（或等价）
- 或补充到 `docs/runbooks/local-dev.md`
