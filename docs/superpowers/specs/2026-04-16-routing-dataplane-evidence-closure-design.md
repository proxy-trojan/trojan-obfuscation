# Routing Dataplane Evidence Closure 设计规格（A2 / 三平台）

## 1. 背景

在 `v1.5.0-beta.1` 后，客户端已具备 routing 配置、规则编辑、序列化与基础决策能力，但“数据面是否真实按规则生效”仍缺少统一、可回归、可跨平台对账的强证据闭环。

本规格用于定义下一阶段工作：在 **Linux + Windows + macOS** 上，建立可控测试流量下的 routing 数据面证据链，形成可自动化验证的 A2 强证据闭环。

---

## 2. 本轮已确认决策（用户拍板）

- 方向：**A Runtime 数据面闭环**
- 强度：**A2 强证据闭环**
- 平台范围：**Linux + Windows + macOS**
- 证据层级：**数据面证据**（可控测试流量下验证）

---

## 3. 目标与非目标

## 3.1 目标

1. 在三平台使用统一场景集证明 routing 数据面行为可验证。
2. 每个场景都能产出结构化证据，覆盖命中、决策、观测结果、回退原因。
3. 证据进入 diagnostics/export 链路，支持回归与排障。
4. 形成可接入 CI 的判定逻辑与失败矩阵报告。

## 3.2 非目标

1. 不做真实公网长时 canary 验证。
2. 不在本阶段实现完整远程 rule-set 分发系统。
3. 不覆盖全部复杂 TUN 场景。

---

## 4. 方案对比与选型

### R1 轻量证据链（偏控制面）
- 以配置渲染 + controller 事件为主。
- 优点：改动小、交付快。
- 缺点：对数据面真实命中证明不足。

### R2 受控数据面探针闭环（推荐）
- 在可控流量下完成 `规则命中 -> 路由决策 -> 实际观测 -> 证据落盘`。
- 优点：证据强度满足 A2，且具备回归价值。
- 缺点：需新增测试基建与平台 adapter。

### R3 准生产外网验证
- 引入真实网络环境长时验证。
- 优点：真实性最强。
- 缺点：成本高、环境噪声大，不适合作为当前主线。

**结论：采用 R2。**

---

## 5. 验收口径（Definition of Done）

三平台均需通过统一核心 6 类场景：

1. `rule -> direct`
2. `rule -> proxy`
3. `rule -> policyGroup`
4. `policyGroup missing -> default fallback`
5. `no rule matched -> default`
6. `block action -> explicit deny evidence`

每个场景证据至少包含：
- `requestFingerprint`
- `matchedRuleId` / `policyGroupId`
- `decisionAction`
- `observedResult`
- `explain`
- `timestamp`
- `platform`

CI 需输出可追溯失败矩阵：`scenario x platform x errorType`。

---

## 6. 架构设计

## 6.1 模块划分

1. **Scenario 定义层**
   - 定义输入请求、预期动作、预期观测。
   - 保证三平台共享同一场景语义。

2. **Runtime 执行与探针层**
   - 复用现有 controller/runtime 路径。
   - 通过平台 adapter 注入可控测试流量与观测逻辑。

3. **Evidence 收集层**
   - 统一证据模型与序列化格式。
   - 将结果写入 diagnostics/export 可消费结构。

4. **Verdict 判定层**
   - 比对 expected vs observed。
   - 输出 `pass / fail / not_applicable`，并给出失败解释。

## 6.2 数据流

`Scenario` -> `Profile/Routing Config` -> `Controller Connect` -> `Probe Traffic` -> `Routing Decision + Observation` -> `Evidence Record` -> `Verdict Report`

---

## 7. 代码边界与改动面

## 7.1 新增模块（建议路径）

- `client/lib/features/routing/testing/domain/`
  - `routing_probe_scenario.dart`
  - `routing_probe_expectation.dart`
  - `routing_probe_observation.dart`

- `client/lib/features/routing/testing/application/`
  - `routing_probe_runner.dart`
  - `routing_probe_verdict_service.dart`

- `client/lib/features/routing/testing/platform/`
  - `routing_probe_adapter.dart`
  - `routing_probe_adapter_linux.dart`
  - `routing_probe_adapter_windows.dart`
  - `routing_probe_adapter_macos.dart`

- `client/lib/features/diagnostics/domain/`
  - `routing_evidence_record.dart`

## 7.2 对现有模块的最小改动

- `adapter_backed_client_controller.dart`
  - 增加可选 evidence hook 注入点。
- `diagnostics_export_service.dart`
  - 增加 routing evidence 导出片段。

## 7.3 三条硬约束

1. 默认生产路径不启用 probe 逻辑。
2. 证据结构保持稳定，后续仅做向后兼容扩展。
3. 平台差异只在 adapter 层处理，上层 runner/verdict 不做 OS 分支。

---

## 8. 错误处理与回退策略

## 8.1 统一错误分类

- `controller_failure`
- `probe_execution_failure`
- `decision_mismatch`
- `observation_mismatch`
- `platform_capability_gap`
- `export_failure`

## 8.2 回退策略

- 业务路由回退严格沿用既有 `defaultAction` 语义。
- 单场景失败不终止整批；整批继续执行并汇总。
- 能力缺口必须显式标注 `not_applicable`，不得静默吞掉。

## 8.3 失败证据最小字段

- `scenarioId`
- `platform`
- `phase`（connect/probe/decision/observe/export）
- `errorType`
- `errorDetail`
- `fallbackApplied`
- `timestamp`

## 8.4 判定规则

- 任一 `decision_mismatch` / `observation_mismatch` -> 场景 Fail。
- `platform_capability_gap` -> 场景 N/A（可见且可追踪）。
- `controller_failure` 超过阈值 -> 本轮 Fail。

## 8.5 超时策略

- 单场景超时上限。
- 批次总超时上限。
- 证据导出失败单独计入 `export_failure`，不覆盖原始失败原因。

---

## 9. 实施批次与门禁

## Batch 1：证据模型 + Runner 骨架

**交付**
- 场景/观测/证据数据结构
- Runner + Verdict 基础实现
- 单平台 mock adapter 打通

**门禁**
- domain/application 单测通过
- 不影响现有连接主路径行为

## Batch 2：Linux 真链路闭环

**交付**
- Linux adapter 接入受控流量
- 核心 6 场景 Linux 跑通
- diagnostics/export 可见结构化证据

**门禁**
- Linux 核心场景全通过
- 证据字段完备且稳定输出

## Batch 3：Windows + macOS 接入

**交付**
- Windows/macOS adapter
- 三平台统一场景执行报告
- capability gap 显式标记

**门禁**
- 三平台结果可对账
- N/A 仅出现在声明缺口场景

## Batch 4：CI Gate 固化

**交付**
- 新增 routing dataplane evidence targeted gate
- 失败矩阵作为 CI artifact 发布

**门禁**
- CI 可稳定复现并阻断回归
- 可作为后续 beta 放行证据之一

---

## 10. 风险与缓解

1. **平台行为差异导致误报**
   - 以 adapter 层能力声明 + N/A 机制隔离。
2. **测试链路侵入生产路径**
   - probe 通过显式开关/注入启用，默认关闭。
3. **证据格式漂移导致比对失效**
   - 固定 schema + 兼容扩展策略。
4. **CI 运行时长上升**
   - 将 gate 设计为 targeted、分层执行。

---

## 11. 结论

本规格确定采用 **R2（受控数据面探针闭环）**，并以四批次实施完成 A2 三平台强证据目标。该路线在证据强度、交付成本与可回归性之间达到当前阶段最优平衡。
