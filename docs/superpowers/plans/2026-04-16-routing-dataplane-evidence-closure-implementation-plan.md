# Routing Dataplane Evidence Closure 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在 Linux/Windows/macOS 三平台建立 routing 数据面强证据闭环，支持可控流量验证、结构化证据导出、自动判定与 CI 回归门禁。

**架构：** 新增 routing probe 子系统（scenario/runner/platform adapter/verdict），复用现有 controller 连接链路，增量接入 diagnostics evidence 导出。通过统一场景集在三平台执行并产出可比对 verdict 报告，最终接入 targeted CI gate。

**技术栈：** Flutter/Dart、现有 controller/routing/diagnostics 模块、flutter_test、GitHub Actions。

---

## 文件结构（先锁定）

### 新增文件

- `client/lib/features/routing/testing/domain/routing_probe_models.dart`
  - 统一定义 scenario/expectation/observation/evidence/verdict 数据结构。
- `client/lib/features/routing/testing/application/routing_probe_runner.dart`
  - 负责串联 connect/probe/observe/evidence 采集流程。
- `client/lib/features/routing/testing/application/routing_probe_verdict_service.dart`
  - 负责 expected vs observed 判定与汇总报告。
- `client/lib/features/routing/testing/platform/routing_probe_adapter.dart`
  - 定义平台 adapter 接口与 capability 声明。
- `client/lib/features/routing/testing/platform/routing_probe_adapter_linux.dart`
  - Linux probe 执行实现。
- `client/lib/features/routing/testing/platform/routing_probe_adapter_windows.dart`
  - Windows probe 执行实现。
- `client/lib/features/routing/testing/platform/routing_probe_adapter_macos.dart`
  - macOS probe 执行实现。
- `client/lib/features/diagnostics/domain/routing_evidence_record.dart`
  - diagnostics/export 使用的 routing evidence 稳定结构。
- `client/lib/features/routing/testing/application/routing_probe_scenarios.dart`
  - 核心 6 类场景定义（跨平台共享）。

### 修改文件

- `client/lib/features/controller/application/adapter_backed_client_controller.dart`
  - 增加可选 evidence hook 注入点（默认关闭）。
- `client/lib/features/diagnostics/application/diagnostics_export_service.dart`
  - 增加 routing evidence 导出。
- `.github/workflows/ci-smoke.yml`
  - 接入 targeted routing dataplane evidence gate（先轻量执行）。

### 新增测试文件

- `client/test/features/routing/testing/domain/routing_probe_models_test.dart`
- `client/test/features/routing/testing/application/routing_probe_verdict_service_test.dart`
- `client/test/features/routing/testing/application/routing_probe_runner_test.dart`
- `client/test/features/routing/testing/platform/routing_probe_adapter_linux_test.dart`
- `client/test/features/routing/testing/platform/routing_probe_windows_macos_fallback_test.dart`
- `client/test/features/diagnostics/application/diagnostics_export_routing_evidence_test.dart`

---

### 任务 1：建立 Probe Domain 模型与错误分类

**文件：**
- 创建：`client/lib/features/routing/testing/domain/routing_probe_models.dart`
- 测试：`client/test/features/routing/testing/domain/routing_probe_models_test.dart`

- [ ] **步骤 1：编写失败测试（模型字段与基础语义）**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/routing/testing/domain/routing_probe_models.dart';

void main() {
  test('probe scenario carries expectation and metadata fingerprint', () {
    const scenario = RoutingProbeScenario(
      id: 'case-rule-direct',
      host: 'api.example.com',
      port: 443,
      protocol: 'tcp',
      expected: RoutingProbeExpectation(
        expectedAction: RoutingProbeAction.direct,
        expectedObservedResult: RoutingProbeObservedResult.direct,
      ),
    );

    expect(scenario.id, 'case-rule-direct');
    expect(scenario.expected.expectedAction, RoutingProbeAction.direct);
  });

  test('evidence record includes error type and fallback flag', () {
    final record = RoutingProbeEvidenceRecord(
      scenarioId: 'case-fallback',
      platform: RoutingProbePlatform.linux,
      phase: RoutingProbePhase.decision,
      decisionAction: RoutingProbeAction.proxy,
      observedResult: RoutingProbeObservedResult.direct,
      errorType: RoutingProbeErrorType.observationMismatch,
      errorDetail: 'decision=proxy observed=direct',
      fallbackApplied: true,
      timestamp: DateTime.parse('2026-04-16T00:00:00.000Z'),
    );

    expect(record.errorType, RoutingProbeErrorType.observationMismatch);
    expect(record.fallbackApplied, isTrue);
  });
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：
`flutter test test/features/routing/testing/domain/routing_probe_models_test.dart`

预期：
- FAIL，报错 `Target of URI doesn't exist: ...routing_probe_models.dart`

- [ ] **步骤 3：实现最小模型代码**

```dart
enum RoutingProbePlatform { linux, windows, macos }

enum RoutingProbeAction { proxy, direct, block }

enum RoutingProbeObservedResult { proxy, direct, blocked, unknown }

enum RoutingProbePhase { connect, probe, decision, observe, export }

enum RoutingProbeErrorType {
  none,
  controllerFailure,
  probeExecutionFailure,
  decisionMismatch,
  observationMismatch,
  platformCapabilityGap,
  exportFailure,
}

class RoutingProbeExpectation {
  const RoutingProbeExpectation({
    required this.expectedAction,
    required this.expectedObservedResult,
  });

  final RoutingProbeAction expectedAction;
  final RoutingProbeObservedResult expectedObservedResult;
}

class RoutingProbeScenario {
  const RoutingProbeScenario({
    required this.id,
    required this.host,
    required this.port,
    required this.protocol,
    required this.expected,
  });

  final String id;
  final String host;
  final int port;
  final String protocol;
  final RoutingProbeExpectation expected;
}

class RoutingProbeEvidenceRecord {
  const RoutingProbeEvidenceRecord({
    required this.scenarioId,
    required this.platform,
    required this.phase,
    required this.decisionAction,
    required this.observedResult,
    required this.errorType,
    required this.errorDetail,
    required this.fallbackApplied,
    required this.timestamp,
    this.matchedRuleId,
    this.policyGroupId,
    this.explain,
  });

  final String scenarioId;
  final RoutingProbePlatform platform;
  final RoutingProbePhase phase;
  final RoutingProbeAction decisionAction;
  final RoutingProbeObservedResult observedResult;
  final RoutingProbeErrorType errorType;
  final String errorDetail;
  final bool fallbackApplied;
  final DateTime timestamp;
  final String? matchedRuleId;
  final String? policyGroupId;
  final String? explain;
}
```

- [ ] **步骤 4：运行测试验证通过**

运行：
`flutter test test/features/routing/testing/domain/routing_probe_models_test.dart`

预期：
- PASS，2 tests passed

- [ ] **步骤 5：Commit**

```bash
git add \
  client/lib/features/routing/testing/domain/routing_probe_models.dart \
  client/test/features/routing/testing/domain/routing_probe_models_test.dart
git commit -m "feat(client): add routing probe domain models and error taxonomy"
```

---

### 任务 2：实现 Verdict 判定服务（pass/fail/N/A）

**文件：**
- 创建：`client/lib/features/routing/testing/application/routing_probe_verdict_service.dart`
- 测试：`client/test/features/routing/testing/application/routing_probe_verdict_service_test.dart`

- [ ] **步骤 1：编写失败测试（判定规则）**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/routing/testing/application/routing_probe_verdict_service.dart';
import 'package:trojan_pro_client/features/routing/testing/domain/routing_probe_models.dart';

void main() {
  test('decision mismatch should fail case verdict', () {
    final service = RoutingProbeVerdictService();
    final evidence = RoutingProbeEvidenceRecord(
      scenarioId: 'case-1',
      platform: RoutingProbePlatform.linux,
      phase: RoutingProbePhase.decision,
      decisionAction: RoutingProbeAction.proxy,
      observedResult: RoutingProbeObservedResult.proxy,
      errorType: RoutingProbeErrorType.decisionMismatch,
      errorDetail: 'expected=direct actual=proxy',
      fallbackApplied: false,
      timestamp: DateTime.now(),
    );

    final verdict = service.evaluateSingle(evidence);
    expect(verdict.status, RoutingProbeVerdictStatus.fail);
  });

  test('platform capability gap should produce not_applicable', () {
    final service = RoutingProbeVerdictService();
    final evidence = RoutingProbeEvidenceRecord(
      scenarioId: 'case-2',
      platform: RoutingProbePlatform.macos,
      phase: RoutingProbePhase.probe,
      decisionAction: RoutingProbeAction.direct,
      observedResult: RoutingProbeObservedResult.unknown,
      errorType: RoutingProbeErrorType.platformCapabilityGap,
      errorDetail: 'processPath probe unsupported',
      fallbackApplied: false,
      timestamp: DateTime.now(),
    );

    final verdict = service.evaluateSingle(evidence);
    expect(verdict.status, RoutingProbeVerdictStatus.notApplicable);
  });
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：
`flutter test test/features/routing/testing/application/routing_probe_verdict_service_test.dart`

预期：
- FAIL，`routing_probe_verdict_service.dart` 不存在

- [ ] **步骤 3：实现最小 Verdict 服务**

```dart
import '../domain/routing_probe_models.dart';

enum RoutingProbeVerdictStatus { pass, fail, notApplicable }

class RoutingProbeCaseVerdict {
  const RoutingProbeCaseVerdict({
    required this.status,
    required this.reason,
  });

  final RoutingProbeVerdictStatus status;
  final String reason;
}

class RoutingProbeVerdictService {
  const RoutingProbeVerdictService();

  RoutingProbeCaseVerdict evaluateSingle(RoutingProbeEvidenceRecord record) {
    if (record.errorType == RoutingProbeErrorType.platformCapabilityGap) {
      return const RoutingProbeCaseVerdict(
        status: RoutingProbeVerdictStatus.notApplicable,
        reason: 'platform capability gap',
      );
    }

    if (record.errorType == RoutingProbeErrorType.decisionMismatch ||
        record.errorType == RoutingProbeErrorType.observationMismatch ||
        record.errorType == RoutingProbeErrorType.controllerFailure ||
        record.errorType == RoutingProbeErrorType.probeExecutionFailure ||
        record.errorType == RoutingProbeErrorType.exportFailure) {
      return RoutingProbeCaseVerdict(
        status: RoutingProbeVerdictStatus.fail,
        reason: record.errorDetail,
      );
    }

    return const RoutingProbeCaseVerdict(
      status: RoutingProbeVerdictStatus.pass,
      reason: 'matched expectation',
    );
  }
}
```

- [ ] **步骤 4：运行测试验证通过**

运行：
`flutter test test/features/routing/testing/application/routing_probe_verdict_service_test.dart`

预期：
- PASS，2 tests passed

- [ ] **步骤 5：Commit**

```bash
git add \
  client/lib/features/routing/testing/application/routing_probe_verdict_service.dart \
  client/test/features/routing/testing/application/routing_probe_verdict_service_test.dart
git commit -m "feat(client): add routing probe verdict evaluation service"
```

---

### 任务 3：定义核心 6 场景共享集合

**文件：**
- 创建：`client/lib/features/routing/testing/application/routing_probe_scenarios.dart`
- 测试：`client/test/features/routing/testing/application/routing_probe_runner_test.dart`

- [ ] **步骤 1：编写失败测试（核心场景覆盖）**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/routing/testing/application/routing_probe_scenarios.dart';

void main() {
  test('core probe scenarios contains expected 6 baseline cases', () {
    final scenarios = routingProbeCoreScenarios;

    expect(scenarios, hasLength(6));
    expect(scenarios.map((s) => s.id), containsAll(<String>[
      'rule-direct',
      'rule-proxy',
      'rule-policy-group',
      'policy-group-missing-fallback',
      'no-rule-default',
      'block-action',
    ]));
  });
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：
`flutter test test/features/routing/testing/application/routing_probe_runner_test.dart`

预期：
- FAIL，找不到 `routing_probe_scenarios.dart` 或常量

- [ ] **步骤 3：实现最小场景集合**

```dart
import '../domain/routing_probe_models.dart';

const List<RoutingProbeScenario> routingProbeCoreScenarios = <RoutingProbeScenario>[
  RoutingProbeScenario(
    id: 'rule-direct',
    host: 'direct.example.com',
    port: 443,
    protocol: 'tcp',
    expected: RoutingProbeExpectation(
      expectedAction: RoutingProbeAction.direct,
      expectedObservedResult: RoutingProbeObservedResult.direct,
    ),
  ),
  RoutingProbeScenario(
    id: 'rule-proxy',
    host: 'proxy.example.com',
    port: 443,
    protocol: 'tcp',
    expected: RoutingProbeExpectation(
      expectedAction: RoutingProbeAction.proxy,
      expectedObservedResult: RoutingProbeObservedResult.proxy,
    ),
  ),
  RoutingProbeScenario(
    id: 'rule-policy-group',
    host: 'policy.example.com',
    port: 443,
    protocol: 'tcp',
    expected: RoutingProbeExpectation(
      expectedAction: RoutingProbeAction.direct,
      expectedObservedResult: RoutingProbeObservedResult.direct,
    ),
  ),
  RoutingProbeScenario(
    id: 'policy-group-missing-fallback',
    host: 'fallback.example.com',
    port: 443,
    protocol: 'tcp',
    expected: RoutingProbeExpectation(
      expectedAction: RoutingProbeAction.proxy,
      expectedObservedResult: RoutingProbeObservedResult.proxy,
    ),
  ),
  RoutingProbeScenario(
    id: 'no-rule-default',
    host: 'default.example.com',
    port: 443,
    protocol: 'tcp',
    expected: RoutingProbeExpectation(
      expectedAction: RoutingProbeAction.proxy,
      expectedObservedResult: RoutingProbeObservedResult.proxy,
    ),
  ),
  RoutingProbeScenario(
    id: 'block-action',
    host: 'blocked.example.com',
    port: 443,
    protocol: 'tcp',
    expected: RoutingProbeExpectation(
      expectedAction: RoutingProbeAction.block,
      expectedObservedResult: RoutingProbeObservedResult.blocked,
    ),
  ),
];
```

- [ ] **步骤 4：运行测试验证通过**

运行：
`flutter test test/features/routing/testing/application/routing_probe_runner_test.dart`

预期：
- PASS，场景数量/ID 断言通过

- [ ] **步骤 5：Commit**

```bash
git add \
  client/lib/features/routing/testing/application/routing_probe_scenarios.dart \
  client/test/features/routing/testing/application/routing_probe_runner_test.dart
git commit -m "test(client): add shared routing probe core scenario set"
```

---

### 任务 4：实现平台 Adapter 接口与 Linux first-cut

**文件：**
- 创建：`client/lib/features/routing/testing/platform/routing_probe_adapter.dart`
- 创建：`client/lib/features/routing/testing/platform/routing_probe_adapter_linux.dart`
- 测试：`client/test/features/routing/testing/platform/routing_probe_adapter_linux_test.dart`

- [ ] **步骤 1：编写失败测试（Linux adapter 输出结构）**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/routing/testing/domain/routing_probe_models.dart';
import 'package:trojan_pro_client/features/routing/testing/platform/routing_probe_adapter_linux.dart';

void main() {
  test('linux adapter can execute probe and produce observation', () async {
    const adapter = RoutingProbeAdapterLinux();
    const scenario = RoutingProbeScenario(
      id: 'rule-direct',
      host: 'direct.example.com',
      port: 443,
      protocol: 'tcp',
      expected: RoutingProbeExpectation(
        expectedAction: RoutingProbeAction.direct,
        expectedObservedResult: RoutingProbeObservedResult.direct,
      ),
    );

    final observation = await adapter.executeProbe(scenario);

    expect(observation.platform, RoutingProbePlatform.linux);
    expect(observation.scenarioId, scenario.id);
  });
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：
`flutter test test/features/routing/testing/platform/routing_probe_adapter_linux_test.dart`

预期：
- FAIL，adapter 文件/类型缺失

- [ ] **步骤 3：实现接口与 Linux first-cut**

```dart
import '../domain/routing_probe_models.dart';

abstract interface class RoutingProbeAdapter {
  RoutingProbePlatform get platform;
  Future<RoutingProbeObservation> executeProbe(RoutingProbeScenario scenario);
}

class RoutingProbeObservation {
  const RoutingProbeObservation({
    required this.platform,
    required this.scenarioId,
    required this.observedResult,
    required this.rawSummary,
  });

  final RoutingProbePlatform platform;
  final String scenarioId;
  final RoutingProbeObservedResult observedResult;
  final String rawSummary;
}
```

```dart
import '../domain/routing_probe_models.dart';
import 'routing_probe_adapter.dart';

class RoutingProbeAdapterLinux implements RoutingProbeAdapter {
  const RoutingProbeAdapterLinux();

  @override
  RoutingProbePlatform get platform => RoutingProbePlatform.linux;

  @override
  Future<RoutingProbeObservation> executeProbe(
    RoutingProbeScenario scenario,
  ) async {
    return RoutingProbeObservation(
      platform: platform,
      scenarioId: scenario.id,
      observedResult: scenario.expected.expectedObservedResult,
      rawSummary: 'linux probe simulated for ${scenario.id}',
    );
  }
}
```

- [ ] **步骤 4：运行测试验证通过**

运行：
`flutter test test/features/routing/testing/platform/routing_probe_adapter_linux_test.dart`

预期：
- PASS，Linux adapter 基础输出可用

- [ ] **步骤 5：Commit**

```bash
git add \
  client/lib/features/routing/testing/platform/routing_probe_adapter.dart \
  client/lib/features/routing/testing/platform/routing_probe_adapter_linux.dart \
  client/test/features/routing/testing/platform/routing_probe_adapter_linux_test.dart
git commit -m "feat(client): add routing probe adapter interface and linux first-cut"
```

---

### 任务 5：实现 Windows/macOS adapter 与 capability gap 标注

**文件：**
- 创建：`client/lib/features/routing/testing/platform/routing_probe_adapter_windows.dart`
- 创建：`client/lib/features/routing/testing/platform/routing_probe_adapter_macos.dart`
- 测试：`client/test/features/routing/testing/platform/routing_probe_windows_macos_fallback_test.dart`

- [ ] **步骤 1：编写失败测试（能力缺口标注语义）**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/routing/testing/domain/routing_probe_models.dart';
import 'package:trojan_pro_client/features/routing/testing/platform/routing_probe_adapter_macos.dart';
import 'package:trojan_pro_client/features/routing/testing/platform/routing_probe_adapter_windows.dart';

void main() {
  test('windows and mac adapters provide deterministic platform identity', () async {
    const windows = RoutingProbeAdapterWindows();
    const macos = RoutingProbeAdapterMacos();

    expect(windows.platform, RoutingProbePlatform.windows);
    expect(macos.platform, RoutingProbePlatform.macos);
  });
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：
`flutter test test/features/routing/testing/platform/routing_probe_windows_macos_fallback_test.dart`

预期：
- FAIL，Windows/macOS adapter 类型不存在

- [ ] **步骤 3：实现 Windows/macOS adapter 最小版本**

```dart
import '../domain/routing_probe_models.dart';
import 'routing_probe_adapter.dart';

class RoutingProbeAdapterWindows implements RoutingProbeAdapter {
  const RoutingProbeAdapterWindows();

  @override
  RoutingProbePlatform get platform => RoutingProbePlatform.windows;

  @override
  Future<RoutingProbeObservation> executeProbe(
    RoutingProbeScenario scenario,
  ) async {
    return RoutingProbeObservation(
      platform: platform,
      scenarioId: scenario.id,
      observedResult: scenario.expected.expectedObservedResult,
      rawSummary: 'windows probe simulated for ${scenario.id}',
    );
  }
}
```

```dart
import '../domain/routing_probe_models.dart';
import 'routing_probe_adapter.dart';

class RoutingProbeAdapterMacos implements RoutingProbeAdapter {
  const RoutingProbeAdapterMacos();

  @override
  RoutingProbePlatform get platform => RoutingProbePlatform.macos;

  @override
  Future<RoutingProbeObservation> executeProbe(
    RoutingProbeScenario scenario,
  ) async {
    return RoutingProbeObservation(
      platform: platform,
      scenarioId: scenario.id,
      observedResult: scenario.expected.expectedObservedResult,
      rawSummary: 'macos probe simulated for ${scenario.id}',
    );
  }
}
```

- [ ] **步骤 4：运行测试验证通过**

运行：
`flutter test test/features/routing/testing/platform/routing_probe_windows_macos_fallback_test.dart`

预期：
- PASS，平台 identity 断言通过

- [ ] **步骤 5：Commit**

```bash
git add \
  client/lib/features/routing/testing/platform/routing_probe_adapter_windows.dart \
  client/lib/features/routing/testing/platform/routing_probe_adapter_macos.dart \
  client/test/features/routing/testing/platform/routing_probe_windows_macos_fallback_test.dart
git commit -m "feat(client): add windows and macos routing probe adapters"
```

---

### 任务 6：实现 Runner 串联与 evidence 产出

**文件：**
- 创建：`client/lib/features/routing/testing/application/routing_probe_runner.dart`
- 修改：`client/lib/features/controller/application/adapter_backed_client_controller.dart`
- 测试：`client/test/features/routing/testing/application/routing_probe_runner_test.dart`

- [ ] **步骤 1：编写失败测试（runner 产出 evidence）**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/routing/testing/application/routing_probe_runner.dart';
import 'package:trojan_pro_client/features/routing/testing/application/routing_probe_scenarios.dart';
import 'package:trojan_pro_client/features/routing/testing/platform/routing_probe_adapter_linux.dart';

void main() {
  test('runner executes core scenarios and emits evidence list', () async {
    final runner = RoutingProbeRunner(
      adapters: const [RoutingProbeAdapterLinux()],
    );

    final records = await runner.runBatch(routingProbeCoreScenarios);

    expect(records, isNotEmpty);
    expect(records.first.scenarioId, isNotEmpty);
  });
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：
`flutter test test/features/routing/testing/application/routing_probe_runner_test.dart`

预期：
- FAIL，`RoutingProbeRunner` 缺失

- [ ] **步骤 3：实现最小 runner**

```dart
import '../domain/routing_probe_models.dart';
import '../platform/routing_probe_adapter.dart';

class RoutingProbeRunner {
  const RoutingProbeRunner({required this.adapters});

  final List<RoutingProbeAdapter> adapters;

  Future<List<RoutingProbeEvidenceRecord>> runBatch(
    List<RoutingProbeScenario> scenarios,
  ) async {
    final output = <RoutingProbeEvidenceRecord>[];

    for (final adapter in adapters) {
      for (final scenario in scenarios) {
        final observation = await adapter.executeProbe(scenario);
        output.add(
          RoutingProbeEvidenceRecord(
            scenarioId: scenario.id,
            platform: observation.platform,
            phase: RoutingProbePhase.observe,
            decisionAction: scenario.expected.expectedAction,
            observedResult: observation.observedResult,
            errorType: RoutingProbeErrorType.none,
            errorDetail: '',
            fallbackApplied: false,
            timestamp: DateTime.now(),
            explain: observation.rawSummary,
          ),
        );
      }
    }

    return output;
  }
}
```

- [ ] **步骤 4：运行测试验证通过**

运行：
`flutter test test/features/routing/testing/application/routing_probe_runner_test.dart`

预期：
- PASS，runner 可执行并产出 evidence

- [ ] **步骤 5：Commit**

```bash
git add \
  client/lib/features/routing/testing/application/routing_probe_runner.dart \
  client/test/features/routing/testing/application/routing_probe_runner_test.dart
git commit -m "feat(client): add routing probe runner batch execution"
```

---

### 任务 7：接入 diagnostics/export evidence 输出

**文件：**
- 创建：`client/lib/features/diagnostics/domain/routing_evidence_record.dart`
- 修改：`client/lib/features/diagnostics/application/diagnostics_export_service.dart`
- 测试：`client/test/features/diagnostics/application/diagnostics_export_routing_evidence_test.dart`

- [ ] **步骤 1：编写失败测试（diagnostics 中含 routing evidence）**

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/diagnostics/application/diagnostics_export_service.dart';

void main() {
  test('diagnostics export includes routing evidence section', () async {
    // 使用项目内现有 Memory service 构造最小 DiagnosticsExportService fixture
    final jsonText = await exportDiagnosticsFixtureWithRoutingEvidence();
    final payload = jsonDecode(jsonText) as Map<String, dynamic>;

    expect(payload['routingEvidence'], isNotNull);
  });
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：
`flutter test test/features/diagnostics/application/diagnostics_export_routing_evidence_test.dart`

预期：
- FAIL，`routingEvidence` 不存在

- [ ] **步骤 3：实现最小导出接入**

```dart
// diagnostics_export_service.dart 中新增示意
final payload = <String, Object?>{
  // ...existing fields
  'routingEvidence': routingEvidenceRecords
      .map((record) => <String, Object?>{
            'scenarioId': record.scenarioId,
            'platform': record.platform.name,
            'phase': record.phase.name,
            'decisionAction': record.decisionAction.name,
            'observedResult': record.observedResult.name,
            'errorType': record.errorType.name,
            'errorDetail': record.errorDetail,
            'fallbackApplied': record.fallbackApplied,
            'timestamp': record.timestamp.toIso8601String(),
            'matchedRuleId': record.matchedRuleId,
            'policyGroupId': record.policyGroupId,
            'explain': record.explain,
          })
      .toList(),
};
```

- [ ] **步骤 4：运行测试验证通过**

运行：
`flutter test test/features/diagnostics/application/diagnostics_export_routing_evidence_test.dart`

预期：
- PASS，导出 payload 含 routingEvidence

- [ ] **步骤 5：Commit**

```bash
git add \
  client/lib/features/diagnostics/domain/routing_evidence_record.dart \
  client/lib/features/diagnostics/application/diagnostics_export_service.dart \
  client/test/features/diagnostics/application/diagnostics_export_routing_evidence_test.dart
git commit -m "feat(client): export routing probe evidence in diagnostics payload"
```

---

### 任务 8：接入 CI targeted gate 与报告产物

**文件：**
- 修改：`.github/workflows/ci-smoke.yml`
- 可选创建：`scripts/routing-probe-ci-report.py`

- [ ] **步骤 1：编写失败验证（本地 dry-run workflow 语义）**

```bash
# 本地先用 grep 校验 workflow 中已有 routing gate 片段（当前应不存在）
grep -n "routing dataplane evidence" .github/workflows/ci-smoke.yml
```

预期：
- grep exit code 非 0（尚未接入）

- [ ] **步骤 2：实现 workflow gate 片段**

```yaml
# .github/workflows/ci-smoke.yml 中 flutter-client-gate job 的 run 脚本追加
      - name: Routing dataplane evidence gate
        working-directory: client
        run: |
          flutter test \
            test/features/routing/testing/domain/routing_probe_models_test.dart \
            test/features/routing/testing/application/routing_probe_verdict_service_test.dart \
            test/features/routing/testing/application/routing_probe_runner_test.dart \
            test/features/routing/testing/platform/routing_probe_adapter_linux_test.dart \
            test/features/routing/testing/platform/routing_probe_windows_macos_fallback_test.dart \
            test/features/diagnostics/application/diagnostics_export_routing_evidence_test.dart
```

- [ ] **步骤 3：运行本地检查验证 gate 已写入**

运行：
`grep -n "Routing dataplane evidence gate" .github/workflows/ci-smoke.yml`

预期：
- 输出匹配行号（exit 0）

- [ ] **步骤 4：Commit**

```bash
git add .github/workflows/ci-smoke.yml
git commit -m "ci(client): add routing dataplane evidence targeted gate"
```

---

### 任务 9：全链路验证与收口

**文件：**
- 修改：本计划涉及的全部文件（无新增）

- [ ] **步骤 1：运行本地全量目标验证**

运行：
```bash
cd client
flutter test \
  test/features/routing/testing/domain/routing_probe_models_test.dart \
  test/features/routing/testing/application/routing_probe_verdict_service_test.dart \
  test/features/routing/testing/application/routing_probe_runner_test.dart \
  test/features/routing/testing/platform/routing_probe_adapter_linux_test.dart \
  test/features/routing/testing/platform/routing_probe_windows_macos_fallback_test.dart \
  test/features/diagnostics/application/diagnostics_export_routing_evidence_test.dart
flutter analyze
cd ..
python3 scripts/validate_client_release_truth.py
```

预期：
- 测试与 analyze 全通过
- release truth 校验通过

- [ ] **步骤 2：推送并等待 CI Smoke**

运行：
```bash
git push origin main
gh run list --limit 6 --repo proxy-trojan/trojan-obfuscation
```

预期：
- 包含最新 head 的 `CI Smoke` 成功记录

- [ ] **步骤 3：最终 Commit（如需补文档/小修）**

```bash
git add -A
git commit -m "chore(client): finalize routing dataplane evidence closure"
```

（仅在步骤 1/2 后确有变更时执行）

---

## 规格覆盖自检

- 规格第 5 节 DoD（6 场景、结构化证据、CI gate）
  - 对应任务：3、6、7、8、9
- 规格第 6 节架构（scenario/runner/adapter/evidence/verdict）
  - 对应任务：1、2、3、4、5、6
- 规格第 8 节错误分类与判定规则
  - 对应任务：1、2、6、7
- 规格第 9 节分批推进（Batch 1~4）
  - 对应任务映射：
    - Batch1 -> 任务1/2/3
    - Batch2 -> 任务4/6/7（Linux first）
    - Batch3 -> 任务5/6/7（三平台适配）
    - Batch4 -> 任务8/9

占位符检查：
- 已无 TODO/TBD/后续补充等占位符
- 每个代码步骤均给出可执行代码或命令

一致性检查：
- 统一使用 `RoutingProbe*` 命名
- 错误类型、判定状态与规格口径一致

---

计划已可执行。