# Iteration 2 Issue Pack — Recovery Ladder 1.0

> 目标：把“失败后不知道怎么办”的体验收敛为可执行、可验证、可支持的 recovery ladder；确保 readiness recommendation 与 failure family 在 Profiles / Dashboard / Diagnostics 三处口径一致。

**Milestone**：`Iter-2: Recovery Ladder 1.0`

**Release Train 对齐**：本包默认按硬 Gate 设计（macOS/Windows/Linux 三平台需一致通过）。

---

## I2-01 Recovery Ladder Policy 中枢（统一动作优先级与文案口径）

**Labels**：`type/feature` `area/client` `priority/P0`

**Background**
- 当前 next action 与 operator advice 规则分布在 Profiles / Dashboard / Controller 多处，易漂移。

**Acceptance Criteria**
- [ ] 新建（或升级）统一 recovery ladder policy 输入输出模型：输入包含 readiness/report、failure family、runtime posture/session truth、recent action。
- [ ] 输出必须稳定给出：`primary action`、`secondary action`（可为空）、`user-facing detail`。
- [ ] 对同一输入，Profiles 与 Dashboard 呈现结果一致（标签 + detail 口径一致）。

**Test / Evidence**
- [ ] 新增 policy 纯单测，覆盖至少 20 个 case（blocked/error/disconnecting/stale/residual）。
- [ ] 回归已有 policy 相关测试全部通过。

**Touched files (expected)**
- `client/lib/features/profiles/presentation/next_action_policy.dart`
- `client/lib/features/dashboard/presentation/dashboard_guide_policy.dart`
- `client/lib/features/controller/domain/runtime_operator_advice.dart`

---

## I2-02 Readiness recommendation 一键闭环（点一下到修复点）

**Labels**：`type/feature` `area/client` `priority/P0`

**Background**
- recommendation 如果只给文案不给精确落点，会导致“知道问题但不知道怎么修”。

**Acceptance Criteria**
- [ ] blocked/degraded recommendation 提供可点击闭环路径（Profiles/Settings/Troubleshooting 对应入口）。
- [ ] 无对应入口时必须回退到明确可达入口，并带“为何回退”的 detail。
- [ ] 点击动作后要有最小 telemetry 记录（action id + source + readiness domain）。

**Test / Evidence**
- [ ] widget test 覆盖 recommendation CTA 点击后路由/回调触发。
- [ ] application/domain test 覆盖 fallback 行为。

**Touched files (expected)**
- `client/lib/features/profiles/presentation/profiles_page.dart`
- `client/lib/features/dashboard/presentation/dashboard_page.dart`
- `client/lib/features/readiness/application/readiness_service.dart`

---

## I2-03 Top5 failure family recovery ladder（可自救或明确升级路径）

**Labels**：`type/feature` `area/client` `priority/P0`

**Background**
- Iter-2 主目标之一：Top5 失败场景 60 秒内知道下一步。

**Acceptance Criteria**
- [ ] 至少覆盖 family：`user_input` / `config` / `connect` / `environment` / `export_os`。
- [ ] 每个 family 给出默认主动作 + 可选备用动作 + detail（避免空泛文案）。
- [ ] family=unknown 时必须默认走支持证据保全路径（先保留证据，再重试）。

**Test / Evidence**
- [ ] 补齐 `next_action_policy_test.dart` 对 Top5 + unknown 的完整断言。
- [ ] 补齐 dashboard guide policy 对应断言。

**Touched files (expected)**
- `client/lib/features/profiles/presentation/next_action_policy.dart`
- `client/lib/features/dashboard/presentation/dashboard_guide_policy.dart`
- `client/test/features/profiles/presentation/next_action_policy_test.dart`

---

## I2-04 Troubleshooting 证据优先（stop-pending / stale / residual 先保全）

**Labels**：`type/bug` `area/client` `priority/P0`

**Background**
- stop-pending/stale/residual 场景下若先 retry 可能冲掉关键证据。

**Acceptance Criteria**
- [ ] stop-pending/stale/residual 时 primary action 默认优先导向 Troubleshooting（或等价证据页）。
- [ ] detail 明确“先保全证据再重试”的因果关系。
- [ ] 不允许在这三类状态默认主动作是立即 retry。

**Test / Evidence**
- [ ] `runtime_action_safety_test.dart` / `runtime_operator_advice_test.dart` 增补断言。
- [ ] Profiles / Dashboard 相关 widget test 回归。

**Touched files (expected)**
- `client/lib/features/controller/domain/runtime_action_safety.dart`
- `client/lib/features/controller/domain/runtime_operator_advice.dart`
- `client/lib/features/profiles/presentation/profile_connection_action_policy.dart`

---

## I2-05 Recovery telemetry 指标闭环（建议→执行→结果）

**Labels**：`type/feature` `area/client` `priority/P1`

**Background**
- 现在有 `recovery_suggested`，但缺“建议是否被执行/是否有效”的追踪闭环。

**Acceptance Criteria**
- [ ] 新增 recovery action 执行事件（至少记录 action type/source/family/runtime posture）。
- [ ] 新增 recovery outcome 事件（success/fail/abandon）。
- [ ] 事件字段在 event dictionary 与计算脚本中可解析。

**Test / Evidence**
- [ ] `ux_metric_event_mapper_test.dart` 与 `ux_metric_service_test.dart` 补充断言。
- [ ] `scripts/tests/test_compute_ux_metrics_snapshot.py` 补充样本与断言。

**Touched files (expected)**
- `client/lib/features/analytics/application/ux_metric_event_mapper.dart`
- `client/lib/features/analytics/application/ux_metric_service.dart`
- `scripts/ux/compute_ux_metrics_snapshot.py`

---

## I2-06 Recovery 命令包验证脚本（Iter-2 gate）

**Labels**：`type/release` `area/ci` `priority/P0`

**Background**
- Iter-1 已有命令包；Iter-2 需要新增 recovery 相关关键测试组合。

**Acceptance Criteria**
- [ ] 新增/升级脚本：包含 flutter analyze + recovery ladder 关键 tests + python metrics snapshot test。
- [ ] 命令输出可直接粘贴到 PR body 作为 gate evidence。

**Test / Evidence**
- [ ] `./scripts/validate_iter2_recovery_ladder.sh`（或在 iter1 脚本中加 iter2 目标）执行通过。

**Touched files (expected)**
- `scripts/validate_iter2_recovery_ladder.sh`
- `.github/workflows/ci-smoke.yml`（如需新增 step）

---

## I2-07 Runbook：Recovery ladder triage（support/自救手册）

**Labels**：`documentation` `type/docs` `priority/P1`

**Background**
- 需要把 failure family → action ladder → evidence export 的路径写成操作手册，降低支持沟通成本。

**Acceptance Criteria**
- [ ] 新增 runbook，包含 Top5 family 的“先做什么、再做什么、何时升级支持”。
- [ ] 明确 stop-pending/stale/residual 的证据保全顺序。
- [ ] 与现有 `first-connect-a1.md` 互相引用，避免重复冲突。

**Touched files (expected)**
- 新增：`docs/runbooks/recovery-ladder-a1.md`
- 更新：`docs/README.md`

---

## I2-08 Desktop validation matrix（Iter-2 rows）

**Labels**：`documentation` `type/docs` `priority/P1`

**Background**
- 验证矩阵需持续承接 Iter-2 gate，确保每个 beta cut 有三平台证据。

**Acceptance Criteria**
- [ ] 在 `docs/desktop-validation-matrix.md` 增加 Iter-2 行（Top5 recovery、recommendation closure、evidence-first rule）。
- [ ] 三平台记录模板包含版本/commit/证据指针。

**Touched files (expected)**
- `docs/desktop-validation-matrix.md`

---

## 建议执行顺序（严格）

1. `I2-01` policy 中枢
2. `I2-03` Top5 family ladder
3. `I2-04` evidence-first rule
4. `I2-02` recommendation 一键闭环
5. `I2-05` telemetry 闭环
6. `I2-06` 命令包验证
7. `I2-07` runbook
8. `I2-08` validation matrix

> 原则：先把“决策真相”收敛，再做入口闭环与观测，最后补文档与矩阵证据。
