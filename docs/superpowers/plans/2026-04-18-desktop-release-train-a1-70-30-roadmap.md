# Desktop Release Train (A1, 70/30) 产品迭代路线图（8 周）

> **面向 AI 代理的工作者：** 这是“产品迭代安排 + 验收模板”的路线图，不是具体实现计划。若要进入实现，请基于本路线图再拆 `docs/superpowers/plans/YYYY-MM-DD-<feature>-implementation-plan.md`。

**目标：**
用 8 周（4 个两周迭代）把桌面产品（macOS/Windows/Linux）推进到“小范围技术内测可持续使用”的状态：
- 首次连接成功更确定（FCSR）
- 日常操作更低摩擦（HFE）
- 失败可自救、可支持（SSR/STE）
- 交付可验证（release truth + CI gates）

**资源配比：** Client 70% / Core 30%

---

## 0. Release Train 规则（摘要）

### 硬 Gate（每个 beta cut 三平台必须通过）
1) Install/Launch/Exit 语义真实
2) Profile + Secret 可用（secure vs fallback 明示）
3) Connect Test 仅认 runtime-true session-ready
4) failure family + next action 可点击闭环
5) Diagnostics 可交付（摘要 + 默认脱敏 + bundle 导出）
6) Release truth（版本/通道/产物/CI 一致）

### 软 Gate（允许单平台延后一迭代）
- tray/快捷入口 UI
- update check 细节
- 性能优化
- UI polish

### 平台差异预算
- 每个平台 ≤2 个软差异同时存在
- 任意差异最多存活 2 个迭代

---

## 1. 迭代安排（4 个两周迭代）

### Iteration 1（Week 1–2）— First Connect Path 1.0（主攻 FCSR）
**Client P0**
- Profiles 内联首次连接主路径（导入/新建→readiness→一键 connect test）
- 连接阶段 timeline + failure family + next action（按钮闭环）
- 存储真相一致：secure storage vs fallback 会话存储必须显式

**Core P0**
- 最小失败分类/错误码稳定输出（供 client 映射）
- stop/shutdown 语义可靠（避免 UI truth 与 runtime truth 冲突）

**验收模板（每平台）**
- [ ] 从 0 到 connect test ≤15 分钟（按文档可复现）
- [ ] 失败必有 next action
- [ ] support bundle 可导出（默认脱敏）

---

### Iteration 2（Week 3–4）— Recovery Ladder 1.0（主攻 SSR）
**Client P0**
- 失败→自救动作梯子（按 family 推荐默认动作）
- readiness recommendation 一键闭环（点一下能到修复点）

**Core P0**
- preflight/配置校验前移（启动前拒绝并解释）
- 最小 soak（先 Linux）并建立回归入口

**验收模板（每平台）**
- [ ] Top5 常见失败可自救或明确下一步
- [ ] Troubleshooting 能看到关键证据
- [ ] 导出摘要与导出 payload 口径一致

---

### Iteration 3（Week 5–6）— Truthful Daily Use 1.0（主攻 HFE + 真相一致）
**Client P0**
- 高频动作入口稳定（quick connect/disconnect/switch + last-known-good）
- 关键页面 truth 口径一致（live/stale/residual）

**Core P0**
- 性能 baseline（连接耗时/CPU/内存）+ 退化阈值

**验收模板（每平台）**
- [ ] 高频动作无误导（状态一致）
- [ ] 性能指标有 baseline 与回归告警

---

### Iteration 4（Week 7–8）— Update Check + Release Truth（降低内测摩擦）
**Client P0**
- update channel 真实 check（先不做自动安装）
- 版本真相一屏（运行/打包/通道/上次检查结果一致）

**Core P0**
- 稳定性卫生（至少 1 lane 强化检查：sanitizer/边界输入）

**验收模板（每平台）**
- [ ] 能回答：当前版本/是否有更新/失败原因/下一步
- [ ] release notes 标注平台差异（若有）

---

## 2. 证据输出规范（每个 beta cut 必须附带）

- flutter analyze 输出（或 CI run 指针）
- flutter test 关键组合输出（或 CI run 指针）
- support bundle 样本（路径/哈希/摘要）
- 平台差异清单（软 Gate）+ 还债迭代

---

## 3. 如何把路线图变成可执行工作

建议做法：
1) 为每个 Iteration 建一个 GitHub Milestone（或等价看板）
2) 按 P0 拆 issue：每个 issue 必须有
   - 明确验收点
   - 可验证命令/证据
3) 若要进入实现：为每个 P0 写 implementation plan，并用 TDD 推进

---

路线图已完成并保存到本文件。下一步如果要我继续：我可以把每个 Iteration 的 P0 拆成 10~15 个可直接创建 issue 的条目（含标题、验收、证据、风险）。
