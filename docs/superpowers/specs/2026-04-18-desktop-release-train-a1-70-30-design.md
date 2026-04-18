# Desktop Release Train (A1, 70/30) 设计规格

> **面向 AI 代理的工作者：** 这是产品迭代与发布节奏的规格说明，不包含实现步骤。

**目标：**
在 **macOS / Windows / Linux** 三平台同时推进时，保证每个 beta cut 都满足“产品本质”（可用、可信、可支持、可交付），同时允许非本质差异以可控预算存在，避免被单平台软问题拖死。

**范围：**
- 覆盖 v1.5.x → v1.7（未来 8 周）的桌面内测（小范围技术用户）发布节奏与验收规则。
- 覆盖 Client 产品化（70%）与 Core 稳定性/性能（30%）的并行治理。

**非目标：**
- 不讨论对外大规模公测发布策略（support/签名/分发规模化）。
- 不讨论任何规避监管/对抗检测类策略或能力扩展。

---

## 1. 项目本质（North Star）

该项目作为产品线的本质是：
1) **Trojan core（C++）稳定可用且可交付**（多平台构建、稳定运行、错误可解释）
2) **Desktop client（Flutter）让用户真实用起来**（首次连接成功、日常操作效率、失败可自救）
3) **Release/Diagnostics 将交付变成确定性**（CI gate、artifact 验证、证据链可导出）

所有迭代与发布规则必须围绕以上三条，避免“协议/能力动物园”式漂移。

---

## 2. 产品指标（A1 内测口径）

### 2.1 北极星指标（主攻）
- **FCSR**（First-Connect Success Rate）：首次连接成功率
  - 成功口径：仅当达到 **runtime-true session-ready** 才计入成功。
- **HFE**（High-Frequency Efficiency）：高频操作效率
  - 关注动作：connect / disconnect / switch profile

### 2.2 护栏指标（不得退化）
- **SSR**（Self-Service Recovery）：失败后的自助恢复率
- **STE**（Support Triage Efficiency）：支持分诊效率（bundle 一眼可分诊）
- **Release truth**：版本/通道/产物一致性（避免支持地狱）

---

## 3. Release Train（分层推进）规则

### 3.1 平台范围
- 目标平台：macOS / Windows / Linux
- 允许平台差异，但必须在预算内并可追踪。

### 3.2 硬 Gate（每个 beta cut 三平台都必须过）
硬 Gate 定义“产品本质”，任何平台未通过则该 cut 不发布。

1. **Install/Launch/Exit 语义真实**
   - 启动/退出/重复启动/停止行为不误导用户。
2. **Profile + Secret 可用**
   - profile 导入/创建可用；密码存储路径必须对用户透明（secure vs fallback）。
3. **Connect Test 真成功口径**
   - 仅认 runtime-true session-ready 为成功；stub/fallback 不得冒充成功。
4. **失败必须可行动**
   - failure family + next action（可点击闭环）。
5. **Diagnostics 可交付**
   - 导出前摘要 + 默认脱敏 + support bundle 导出成功。
6. **Release truth**
   - 版本/通道/产物/CI gate 口径一致。

### 3.3 软 Gate（允许单平台落后一迭代）
软 Gate 必须满足：
- 写入 release notes 的“平台差异 / 已知限制”；
- 明确修复计划（最多落后 1 个迭代）；
- 不得破坏任何硬 Gate。

典型软 Gate：
- tray/快捷入口 UI 差异
- update check 的细节完善（先 check，再 install）
- 性能优化（先 baseline + 退化告警）
- UI polish

### 3.4 平台差异预算（防分叉）
- 每个平台同时允许存在的软差异 ≤ 2 个。
- 任意差异最多存活 2 个迭代；超过则必须升为 P0 还债或砍掉。

---

## 4. 迭代节奏（未来 8 周）

### Iteration 1（Week 1–2）：First Connect Path 1.0
- 主攻：FCSR
- 主题：Profiles 内联引导 + readiness 阻塞项前置 + 连接阶段反馈 + 下一步动作

### Iteration 2（Week 3–4）：Recovery Ladder 1.0
- 主攻：SSR
- 主题：失败→自救动作梯子 + readiness recommendation 闭环

### Iteration 3（Week 5–6）：Truthful Daily Use 1.0
- 主攻：HFE（并确保 truth 不打架）
- 主题：高频动作稳定化 + 状态真相一致 + 性能 baseline

### Iteration 4（Week 7–8）：Update Check + Release Truth
- 主攻：降低内测摩擦（不是全自动升级）
- 主题：真实 update check + 版本真相一屏

---

## 5. 验收与证据

### 5.1 验证矩阵
- 每个 beta cut 必须更新一次桌面验证矩阵（按平台打勾）。

### 5.2 证据要求
- 每个硬 Gate 必须有：
  - 测试输出（flutter test / analyze / 关键脚本）
  - 或导出证据（support bundle / snapshot）
  - 或 CI run 指针

---

## 6. 风险与缓解

1) **三平台同时推进导致节奏被拖死**
- 缓解：硬/软 gate 分层 + 差异预算。

2) **UI 优化掩盖 runtime truth**
- 缓解：成功口径锁定 runtime-true；stub/fallback 必须显式。

3) **支持成本失控**
- 缓解：bundle 默认脱敏 + 摘要可读 + failure family 对齐。

---

## 7. 结论

采用“硬 Gate 三平台同步 + 软 Gate 受控差异预算”的 release train，可在不偏离项目本质的前提下，快速提升 A1 内测的首次成功率与稳定日用体验，并保持 core 稳定性与交付确定性。
