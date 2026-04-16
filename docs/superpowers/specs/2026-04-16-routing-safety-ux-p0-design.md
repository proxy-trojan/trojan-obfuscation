# Routing Safety & UX P0 设计规格（v1.5.0 Follow-up）

## 1. 背景

`v1.5.0` 已完成 routing kernel、dataplane evidence 闭环与三平台 targeted gate 基础能力，但要进一步提升真实可用性，当前主矛盾已从“能不能跑”转向“是否稳、是否安全、是否可恢复、是否可诊断”。

本规格定义下一阶段 P0：以 **3 周稳态节奏** 同时覆盖用户体验与流量安全，形成“变更前可预防、变更后可自愈、故障时可定位”的闭环。

---

## 2. 目标与非目标

### 2.1 目标（P0 必须同时达成）

1. **可用性**：避免规则误配导致断网或走错路径。
2. **安全性**：降低异常流量绕过与策略失效风险。
3. **可恢复性**：应用失败可自动回滚并进入安全模式。
4. **可诊断性**：support/diagnostics 可直接定位“哪条规则导致了什么结果”。

### 2.2 非目标（P0 不做）

1. 完整远程 rule-set 分发/签名治理系统。
2. 全量复杂 TUN 与系统级透明代理能力。
3. 自动化策略优化与自适应调参系统。

---

## 3. 已确认产品决策（冻结）

1. 方案路线：**A' 分阶段并行**（体验与安全共同推进，分层收敛）。
2. P0 时间盒：**3 周**。
3. fail-safe 默认动作：**proxy**。
4. 应用后 mini smoke probe 失败：**自动回滚**。
5. anti-flap：**30 分钟内连续 2 次自动回滚 -> quarantine（需手动解锁）**。
6. 自动回滚后：**自动进入 Safe Mode**。

---

## 4. 方案对比与选型

### R1 双轨硬并行（UX 与 Security 完全并发）
- 优点：价值释放快。
- 缺点：上下文切换成本高，范围易膨胀。

### R2 安全底座先行，体验后置
- 优点：风险最低，控制最稳。
- 缺点：早期用户体感提升慢。

### R3 体验先行，安全做最小护栏
- 优点：见效快。
- 缺点：后续补安全债返工概率高。

### 结论：采用 **R1'（分阶段并行）**
以统一 guardrail/evidence 模型为底座，按阶段推进体验与安全能力，兼顾价值释放与风险控制。

---

## 5. 架构设计（P0）

### 5.1 分层结构

1. **Rule Authoring Layer**
   - 规则与策略编辑。
   - 产出结构化变更 diff。

2. **Guardrail Layer**
   - schema 校验、冲突检测、死规则检测。
   - 风险分级与 Hard Block/Soft Warn 判定。

3. **Dry-run & Explain Layer**
   - 核心场景集 before/after 预演。
   - 输出命中链、决策动作、观测结果、风险提示。

4. **Runtime Enforcement Layer**
   - 复用现有 routing kernel 与 dataplane probe。
   - 执行 direct/proxy/block/policyGroup。

5. **Evidence & Diagnostics Layer**
   - 统一写入结构化证据。
   - 支持导出矩阵化报告（scenario × platform × errorType）。

6. **Recovery Layer**
   - last-known-good 快照。
   - 自动回滚、Safe Mode、quarantine 控制。

### 5.2 关键数据流

#### 变更防护流（配置面）
`编辑规则 -> Preflight -> Dry-run 对比 -> 风险评级 -> 确认应用 -> mini smoke probe -> 成功/自动回滚`

#### 异常处置流（运行面）
`运行异常 -> 错误分类 -> fallback/回退 -> evidence 落盘 -> diagnostics 导出 -> 支持定位与恢复`

---

## 6. 功能需求（P0）

### FR-1 Preflight 风险检查

#### Hard Block（禁止应用）
- policyGroup 引用缺失。
- 默认路径不可达（可能全断）。
- 不可解冲突或非法规则结构。

#### Soft Warn（可继续但需确认）
- 过宽匹配可能造成误导流。
- 优先级覆盖导致关键规则失效风险。

### FR-2 Dry-run + Explain + Diff
- 支持核心场景集 before/after 对比。
- 输出字段：`matchedRuleId/policyGroupId/decisionAction/observedResult/explain/riskHint`。
- 明确展示受影响场景和行为变化。

### FR-3 Apply Gate
- Low risk：直接应用。
- Medium/High risk：二次确认后应用。
- 应用后强制 mini smoke probe。

### FR-4 自动回滚 + Safe Mode
- smoke probe 关键失败时自动回滚至 last-known-good。
- 回滚完成后自动进入 Safe Mode，优先恢复可用性。

### FR-5 Anti-flap Quarantine
- 30 分钟内连续 2 次自动回滚则隔离该 candidate。
- quarantined candidate 禁止自动应用，需手动解锁。

### FR-6 Evidence 导出增强
- diagnostics 导出必须包含：
  - `scenarioId/platform/phase/errorType/errorDetail/fallbackApplied/timestamp`
  - `matchedRuleId/policyGroupId/explain/operationId/rollbackReason`
- 输出可用于 CI 与支持排障复盘。

---

## 7. 状态机（用户可见）

`draft -> validated -> applying -> active`

失败分支：
`applying -> rolled_back -> safe_mode_active`

防抖隔离分支：
`rolled_back (x2/30min) -> quarantined`

说明：
- quarantined 状态下仅允许手动解锁或回退至稳定策略。
- 每次状态迁移必须写入审计事件。

---

## 8. 威胁模型与控制映射

1. **误配风险**（高概率）
   - 控制：Preflight Hard Block + Dry-run + 自动回滚。
2. **规则污染风险**（中概率高影响）
   - 控制：P0 先本地 deterministic、source 锁定、checksum 记录。
3. **异常流量/探测风险**（中高概率）
   - 控制：fail-safe=proxy、block evidence、fallbackApplied 可追踪。
4. **证据盲区风险**（高概率）
   - 控制：统一 evidence schema + diagnostics 矩阵导出。

---

## 9. 错误处理策略

### 9.1 错误分类
- `controller_failure`
- `probe_execution_failure`
- `decision_mismatch`
- `observation_mismatch`
- `platform_capability_gap`
- `export_failure`

### 9.2 处理规则
- 关键执行错误 -> 自动回滚 + Safe Mode。
- `platform_capability_gap` -> 标记 `not_applicable`，不得静默吞掉。
- 回滚触发时必须输出 rollback 证据与建议动作。

---

## 10. 测试与发布门禁

### 10.1 测试分层
1. Unit：风险分级、dry-run diff、anti-flap 判定。
2. Integration：apply -> smoke fail -> rollback -> safe mode。
3. Evidence：导出字段完整性与一致性。
4. Platform gate：Linux/Windows/macOS targeted routing evidence gate。

### 10.2 发布门禁
- `flutter analyze` 通过。
- routing targeted tests 通过（含 rollback/quarantine）。
- `CI Smoke` 全绿。
- `Client Packaging` 全绿。
- release truth 校验通过。

---

## 11. 里程碑计划（3 周）

### Week 1：防误配
- Preflight 风险检查。
- Dry-run/Explain/Diff。

### Week 2：自愈闭环
- Apply Gate。
- 自动回滚 + 自动 Safe Mode。
- anti-flap quarantine。

### Week 3：证据与验收
- diagnostics evidence 完整化。
- 三平台 targeted gate 稳定化。
- 发布门禁验收与文档收口。

---

## 12. P0 验收标准（Definition of Done）

1. 高危变更在保存/应用前可阻断（阻断率 100%）。
2. 应用失败场景下自动回滚并进入 Safe Mode（成功率 >= 99%）。
3. 回滚相关证据字段完整率 100%。
4. 异常场景 MTTR 目标 < 60 秒（从检测到可用恢复）。
5. 三平台 targeted routing evidence gate 持续通过。

---

## 13. 结论

P0 采用“**安全默认 + 变更前预演 + 失败自动回滚 + 证据先行**”路线，能够在不扩张协议复杂度的前提下，实质提升用户体验、流量安全与运维可控性，为后续 P1（规则来源签名治理、进阶异常防护）建立稳定基座。
