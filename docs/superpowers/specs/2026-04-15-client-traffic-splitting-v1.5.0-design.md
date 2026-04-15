# Client Traffic Splitting v1.5.0 设计规格（Draft Approved for Planning）

## 1. 背景与目标

当前客户端（`v1.4.0`）侧重 runtime truth、supportability、packaging/release truth，但**尚未具备业务可用的分流能力**。`ClientProfile` 仅包含基础连接参数（host/port/sni/socks port/TLS），`TrojanClientConfigRenderer` 也仅渲染最小 client 配置。

`v1.5.0` 目标：

1. 在现有 desktop-first 架构上引入**可演进、可验证、可观测**的流量分流能力。
2. 吸收主流方案优势（规则匹配表达力、规则集治理、用户体验与安全边界），但不照搬实现。
3. 为后续“远程规则分发、增量更新、策略实验”打下底层基础。

---

## 2. 主流分流思路对比（抽象层）

> 参考维度：规则表达力、规则治理、执行性能、可解释性、运维复杂度。

### A. 静态规则优先（classic rule list）

**做法**：按顺序匹配域名/IP/端口/进程/网络类型，命中即路由到 target（DIRECT/PROXY/REJECT）。

**优点**
- 可读性高， deterministic（顺序明确）
- 适合本地单机策略

**缺点**
- 规则膨胀后维护成本高
- 缺少版本化、来源可信治理时容易失控

### B. 规则集驱动（rule-set / provider）

**做法**：本地仅持“策略骨架”，大规模规则放到可更新的 rule-set（如 geosite/geoip/业务域规则）。

**优点**
- 便于规模化治理与更新
- 可将“策略逻辑”与“规则数据”解耦

**缺点**
- 对签名校验、缓存一致性要求高
- 下载失败、版本漂移会带来不可预期行为

### C. 策略组与分层决策（policy / fallback / chain）

**做法**：规则先映射到策略组（如 `global`, `auto`, `direct`, `block`, `fallback`），再由策略组选择实际 outbound。

**优点**
- 业务语义清晰（用户理解“策略”而非底层细节）
- 便于 A/B、回滚、灰度

**缺点**
- 多一层抽象，初期复杂度增加
- 若缺可观测性，排障难度上升

---

## 3. v1.5.0 设计原则（我们的路线）

1. **策略语义优先，规则实现托底**
   - UI 面向“策略行为”（例如：国内直连、广告拦截、未知走代理）
   - 引擎内部保留规则表达能力
2. **本地 deterministic first，远程更新 second**
   - v1.5.0 首发优先本地可复现
   - 远程 rule-set 更新能力作为可选扩展（不阻断主功能）
3. **可解释路由（Explainability）内建**
   - 每次命中保留 `why matched -> routed to` 的证据摘要
4. **安全边界前置**
   - 规则来源、版本、签名、回滚、失败降级必须明确
5. **与现有 runtime truth 模型兼容**
   - 分流结果要进入 diagnostics/export/support 证据链

---

## 4. 目标架构（v1.5.0）

## 4.1 分层结构

1. **Domain Layer（Routing Domain）**
   - `SplitProfile`：分流配置聚合根
   - `SplitRule`：规则实体（条件+动作+优先级）
   - `RuleSetRef`：规则集引用（本地/远程/内置）
   - `RoutingPolicy`：策略组定义

2. **Application Layer（Routing Orchestration）**
   - `SplitPlanner`：把 profile + ruleSets 编译成运行时计划
   - `SplitValidator`：冲突检测、覆盖率检测、死规则检测
   - `SplitExplainService`：给 UI/diagnostics 提供命中解释

3. **Infrastructure Layer（RuleSet & Runtime Bridge）**
   - `RuleSetStore`：本地缓存与版本管理
   - `RuleSetFetcher`（optional in v1.5.0）：远程拉取
   - `RoutingConfigEmitter`：输出到 Trojan runtime config（或 sidecar config）

4. **Presentation Layer（Profile + Settings + Diagnostics）**
   - Profiles 增加“分流策略”编辑入口
   - Settings 增加全局默认策略与安全开关
   - Diagnostics 增加最近命中规则/失败回退轨迹

## 4.2 决策流（简化）

`request metadata` -> `rule matcher` -> `policy group` -> `outbound decision` -> `evidence log`

---

## 5. 数据模型（初版）

```text
SplitProfile
- id
- name
- mode: rule | global | direct
- defaultPolicy: proxy | direct | block
- ruleRefs: [SplitRule.id]
- ruleSetRefs: [RuleSetRef.id]
- updatedAt

SplitRule
- id
- name
- enabled
- priority (int, lower first)
- match:
  - domain/domainSuffix/domainKeyword/domainRegex
  - ipCidr/ipGeo
  - processName/processPath (platform-gated)
  - port/network
- action:
  - policy: direct|proxy|block|policyGroupRef
- noResolve: bool
- tags: [string]

RuleSetRef
- id
- sourceType: builtin|local|remote
- source
- version
- checksum
- signature(optional v1.5.0 soft)
- lastUpdatedAt
- status: ready|stale|failed
```

---

## 6. 与现有代码的集成策略

## 6.1 不破坏现有主线

- 保持 `ClientProfile` 兼容：新增可选字段，不破坏现有序列化加载。
- `TrojanClientConfigRenderer` 从“最小配置渲染器”升级为“可注入 split plan 的渲染器”。
- `ProfileStore` / `ProfileSerialization` 增量扩展，并提供迁移默认值。

## 6.2 首批落点文件（预计）

- `client/lib/features/routing/**`（新模块）
- `client/lib/features/profiles/domain/client_profile.dart`（扩展字段）
- `client/lib/features/profiles/application/profile_serialization.dart`（版本迁移）
- `client/lib/features/controller/application/trojan_client_config_renderer.dart`（注入 plan）
- `client/lib/features/diagnostics/application/*`（新增 routing evidence）

---

## 7. 质量与验证策略

1. **单元测试（必须）**
   - matcher 行为（域名/IP/端口/进程）
   - priority 决策与冲突场景
   - noResolve 语义
2. **契约测试（必须）**
   - `SplitPlanner -> RoutingConfigEmitter` 输出稳定性
3. **回归测试（必须）**
   - 不启用分流时行为与 v1.4.0 一致
4. **可观测性测试（建议）**
   - 命中解释信息在 diagnostics/export 可见

---

## 8. 版本发布策略（v1.5.0）

- 分支：`feature/v1.5.0-client-splitting`
- 阶段发布：
  1) domain/application 可用 + 单测
  2) UI first-cut + 诊断证据
  3) 打包/CI 全量 gate
- 发布门禁：
  - flutter analyze + target tests + release truth + packaged smoke

---

## 9. 风险与缓解

1. **规则复杂度暴涨**
   - 缓解：规则模板化 + lint + unused/dead rule 提示
2. **远程 rule-set 不稳定**
   - 缓解：本地缓存、版本锁、失败回退到 last-known-good
3. **用户误配导致断网**
   - 缓解：安全模式（保底直连规则 + 一键恢复）
4. **平台差异（process/path）**
   - 缓解：字段 capability gating，非支持平台禁用相关规则

---

## 10. 结论（推荐路线）

采用“**策略语义层 + 可解释规则引擎 + 渐进式规则集治理**”路线：

- 不做纯静态规则堆砌
- 不直接照搬任何现成产品配置结构
- 保留和主流方案同等级的扩展性与治理能力
- 与当前 v1.4.0 runtime truth 主线无缝衔接

该方案已满足进入实现计划阶段。
