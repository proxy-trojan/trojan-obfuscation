# Iter-3: last-known-good quick retry（Profiles HF strip）实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在 Profiles 页 `HighFrequencyActionsStrip` 增加 `Quick Retry (Last Good)` 入口，并按语义 A 执行（先切 selected → 对 last-good preflight → connect），且不绕过 readiness / runtime truth / action-safety gating；补齐 #51 指定 tests 作为证据。

**架构：** 采用 UI 驱动方案：controller 仅暴露只读 `lastKnownGoodProfileId`，Profiles UI 通过 `profileStore` 找到对应 profile 并执行 gated retry。Readiness preflight 扩展为支持 `profileOverride`，反馈统一走 `buildRuntimeActionFeedback(action: RuntimeActionKind.retry, ...)`。

**技术栈：** Flutter/Dart、widget tests（flutter_test）、现有 domain policy（RuntimeActionSafety/Matrix/Feedback）。

---

## 0) 文件清单与职责（本计划涉及）

**修改：**
- `client/lib/features/controller/application/client_controller_api.dart`
  - 新增只读 getter：`String? get lastKnownGoodProfileId`（默认 null）
- `client/lib/features/controller/application/adapter_backed_client_controller.dart`
  - override getter，返回 `_lastKnownGoodProfileId`
- `client/lib/features/controller/application/fake_client_controller.dart`
  - override getter（测试可控，默认 null）
- `client/lib/features/profiles/presentation/high_frequency_actions_strip.dart`
  - 新增按钮与可选回调：`onQuickRetryLastGood`
- `client/lib/features/profiles/presentation/profiles_page.dart`
  - 接入 quick retry：计算 last-good profile、切换 selected、preflight(profileOverride)、connect、SnackBar feedback
  - 改造 `_runConnectReadinessPreflight` 支持 `profileOverride`

**测试：**
- `client/test/features/profiles/presentation/high_frequency_actions_strip_test.dart`
  - 覆盖新按钮渲染与 disabled 行为
- `client/test/features/profiles/presentation/profiles_page_action_gating_test.dart`
  - 新增 quick retry 行为测试（切 selected + preflight + connect）
  - 新增 blocked preflight 测试（不触发 connect，copy truth-safe）

---

# 任务 1：先写 HF strip 的失败测试（红）并验证

**文件：**
- 修改：`client/test/features/profiles/presentation/high_frequency_actions_strip_test.dart`
- 随后实现会修改：`client/lib/features/profiles/presentation/high_frequency_actions_strip.dart`

- [ ] **步骤 1：编写失败的测试（新增按钮渲染）**

在 `high_frequency_actions_strip_test.dart` 追加：

```dart
  testWidgets('renders quick retry (last good) when handler is provided',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HighFrequencyActionsStrip(
            onQuickConnect: () {},
            onQuickDisconnect: () {},
            onSwitchProfile: () {},
            onQuickRetryLastGood: () {},
          ),
        ),
      ),
    );

    expect(find.text('Quick Retry (Last Good)'), findsOneWidget);
  });
```

- [ ] **步骤 2：编写失败的测试（disabled 时新按钮也禁用）**

继续追加：

```dart
  testWidgets('disables quick retry (last good) when disabled flag is true',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HighFrequencyActionsStrip(
            enabled: false,
            onQuickConnect: () {},
            onQuickDisconnect: () {},
            onSwitchProfile: () {},
            onQuickRetryLastGood: () {},
          ),
        ),
      ),
    );

    final retry = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Quick Retry (Last Good)'),
    );
    expect(retry.onPressed, isNull);
  });
```

- [ ] **步骤 3：运行测试验证失败（红灯）**

运行：

```bash
cd client
flutter test test/features/profiles/presentation/high_frequency_actions_strip_test.dart
```

预期：FAIL，报错类似：
- `No named parameter with the name 'onQuickRetryLastGood'.`
- 或找不到 `Quick Retry (Last Good)` 文本。

---

# 任务 2：实现 HF strip 新按钮（绿）并验证

**文件：**
- 修改：`client/lib/features/profiles/presentation/high_frequency_actions_strip.dart`
- 测试：`client/test/features/profiles/presentation/high_frequency_actions_strip_test.dart`

- [ ] **步骤 1：最少实现让测试通过**

在 `HighFrequencyActionsStrip`：
- 构造器新增：`this.onQuickRetryLastGood,`
- 字段：`final VoidCallback? onQuickRetryLastGood;`
- build 中新增 handler：`final retryHandler = enabled ? onQuickRetryLastGood : null;`
- children 里在 Quick Disconnect 之后插入：

```dart
        OutlinedButton(
          onPressed: retryHandler,
          child: const Text('Quick Retry (Last Good)'),
        ),
```

并保持当 handler 为 null 时不渲染按钮（避免 UI 噪音）：

```dart
        if (onQuickRetryLastGood != null)
          OutlinedButton(
            onPressed: retryHandler,
            child: const Text('Quick Retry (Last Good)'),
          ),
```

- [ ] **步骤 2：运行测试验证通过（绿灯）**

```bash
cd client
flutter test test/features/profiles/presentation/high_frequency_actions_strip_test.dart
```

预期：PASS。

- [ ] **步骤 3：Commit**

```bash
cd /root/.openclaw/workspace/trojan-obfuscation
git add \
  client/lib/features/profiles/presentation/high_frequency_actions_strip.dart \
  client/test/features/profiles/presentation/high_frequency_actions_strip_test.dart
git commit -m "feat(client): add last-good quick retry button to hf strip"
```

---

# 任务 3：先写 Profiles quick retry 的失败测试（红）并验证

**文件：**
- 修改：`client/test/features/profiles/presentation/profiles_page_action_gating_test.dart`
- 随后实现会修改：`client/lib/features/controller/application/client_controller_api.dart`
  `client/lib/features/controller/application/fake_client_controller.dart`
  `client/lib/features/profiles/presentation/profiles_page.dart`

## 3.1 测试支撑 controller（在测试文件内新增 stub controller）

- [ ] **步骤 1：在 test 文件内新增一个可控 controller：提供 lastKnownGoodProfileId 且能记录 connect 的 profileId**

在 `profiles_page_action_gating_test.dart`（靠近其他 `_XxxController`）新增：

```dart
class _LastKnownGoodController extends FakeClientController {
  _LastKnownGoodController({
    required this.lastGoodProfileId,
  });

  final String lastGoodProfileId;
  String? lastConnectProfileId;

  @override
  String? get lastKnownGoodProfileId => lastGoodProfileId;

  @override
  Future<ControllerCommandResult> connect(ClientProfile profile) async {
    lastConnectProfileId = profile.id;
    return super.connect(profile);
  }
}
```

- [ ] **步骤 2：编写失败测试：点击 quick retry 会切 selected 并触发 connect(lastGood)**

追加 test：

```dart
  testWidgets('quick retry (last good) switches selected profile then connects',
      (WidgetTester tester) async {
    await _setDesktopSurface(tester);

    final controller = _LastKnownGoodController(lastGoodProfileId: 'sample-hk-2');
    final services = _buildServices(controllerOverride: controller);

    final first = services.profileStore.profiles.first;
    final lastGood = services.profileStore.profiles
        .firstWhere((p) => p.id == 'sample-hk-2');

    await services.profileSecrets.saveTrojanPassword(
      profileId: first.id,
      password: 'secret-1',
    );
    await services.profileSecrets.saveTrojanPassword(
      profileId: lastGood.id,
      password: 'secret-2',
    );
    services.profileStore.upsertProfile(first.copyWith(hasStoredPassword: true));
    services.profileStore
        .upsertProfile(lastGood.copyWith(hasStoredPassword: true));

    services.profileStore.selectProfile(first.id);
    expect(services.profileStore.selectedProfileId, first.id);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProfilesPage(services: services)),
      ),
    );
    await tester.pump();

    final retryButton = find.widgetWithText(
      OutlinedButton,
      'Quick Retry (Last Good)',
    );
    await tester.ensureVisible(retryButton);
    await tester.tap(retryButton);

    // allow controller connect delays in FakeClientController
    await tester.pump(const Duration(milliseconds: 20));

    // Semantics A: selected must switch immediately.
    expect(services.profileStore.selectedProfileId, lastGood.id);

    // connect should be invoked for lastGood.
    expect(controller.lastConnectProfileId, lastGood.id);
  });
```

- [ ] **步骤 3：运行测试验证失败（红灯）**

运行：

```bash
cd client
flutter test test/features/profiles/presentation/profiles_page_action_gating_test.dart
```

预期：FAIL，原因之一应为：
- `ClientControllerApi` 没有 `lastKnownGoodProfileId` getter
- `ProfilesPage` 未渲染按钮
- 或未切 selected / 未触发 connect。

---

# 任务 4：实现 controller API 暴露 lastKnownGoodProfileId（绿）并验证

**文件：**
- 修改：`client/lib/features/controller/application/client_controller_api.dart`
- 修改：`client/lib/features/controller/application/adapter_backed_client_controller.dart`
- 修改：`client/lib/features/controller/application/fake_client_controller.dart`

- [ ] **步骤 1：在 ClientControllerApi 增加默认 getter**

在 `ClientControllerApi` 增加：

```dart
  String? get lastKnownGoodProfileId => null;
```

- [ ] **步骤 2：AdapterBackedClientController override**

在类内增加：

```dart
  @override
  String? get lastKnownGoodProfileId => _lastKnownGoodProfileId;
```

- [ ] **步骤 3：FakeClientController override（默认 null）**

```dart
  @override
  String? get lastKnownGoodProfileId => null;
```

- [ ] **步骤 4：运行 quick retry 测试验证仍失败但失败点前移正确**

```bash
cd client
flutter test test/features/profiles/presentation/profiles_page_action_gating_test.dart
```

预期：依然 FAIL（因为 UI 还没接入），但不再报“getter 不存在”。

- [ ] **步骤 5：Commit**

```bash
cd /root/.openclaw/workspace/trojan-obfuscation
git add \
  client/lib/features/controller/application/client_controller_api.dart \
  client/lib/features/controller/application/adapter_backed_client_controller.dart \
  client/lib/features/controller/application/fake_client_controller.dart
git commit -m "feat(client): expose last known good profile id on controller api"
```

---

# 任务 5：实现 ProfilesPage quick retry（含 preflight profileOverride）让测试通过（绿）

**文件：**
- 修改：`client/lib/features/profiles/presentation/profiles_page.dart`

- [ ] **步骤 1：改造 readiness preflight 支持 profileOverride**

将：

```dart
Future<bool> _runConnectReadinessPreflight({ required ScaffoldMessengerState messenger })
```

改成：

```dart
Future<bool> _runConnectReadinessPreflight({
  required ScaffoldMessengerState messenger,
  ClientProfile? profileOverride,
})
```

并在内部使用：

```dart
final targetProfile = profileOverride ?? selected;
final readinessReport = await services.readiness.buildReport(
  profileOverride: targetProfile,
);
```

- [ ] **步骤 2：在 ProfilesPage 构建 lastGoodProfile + handler**

在 `HighFrequencyActionsStrip(...)` 参数中新增：
- 计算：

```dart
final lastGoodId = services.controller.lastKnownGoodProfileId;
final lastGoodProfile = (lastGoodId == null)
    ? null
    : services.profileStore.profiles
        .cast<ClientProfile?>()
        .firstWhere((p) => p?.id == lastGoodId, orElse: () => null);
final canQuickRetryLastGood = lastGoodProfile != null &&
    lastGoodProfile.id != selected.id &&
    status.phase != ClientConnectionPhase.connected;
```

- 传入 strip：

```dart
onQuickRetryLastGood: !canQuickRetryLastGood
    ? null
    : () async {
        final messenger = ScaffoldMessenger.of(context);

        // Semantics A: switch selected first.
        services.profileStore.selectProfile(lastGoodProfile.id);

        final allowed = await _runConnectReadinessPreflight(
          messenger: messenger,
          profileOverride: lastGoodProfile,
        );
        if (!mounted || !allowed) {
          return;
        }

        final result = await services.controller.connect(lastGoodProfile);
        if (!mounted) return;
        final feedback = buildRuntimeActionFeedback(
          action: RuntimeActionKind.retry,
          result: result,
          status: services.controller.status,
          session: services.controller.session,
          posture: _runtimePosture,
        );
        messenger.showSnackBar(SnackBar(content: Text(feedback)));
      },
```

注意：strip 仍保持 `enabled: connectionPolicy.canToggleConnection`（不绕过 action-safety gating）。

- [ ] **步骤 3：运行 ProfilesPage gating tests 验证通过（绿）**

```bash
cd client
flutter test test/features/profiles/presentation/profiles_page_action_gating_test.dart
```

预期：PASS。

- [ ] **步骤 4：Commit**

```bash
cd /root/.openclaw/workspace/trojan-obfuscation
git add client/lib/features/profiles/presentation/profiles_page.dart
git commit -m "feat(client): quick retry last known good profile from profiles hf strip"
```

---

# 任务 6：补一条 blocked preflight 的 quick retry 测试（红→绿）

**文件：**
- 修改：`client/test/features/profiles/presentation/profiles_page_action_gating_test.dart`

- [ ] **步骤 1：新增失败测试：last-good readiness blocked 时不 connect，且出现 blocked copy**

示例（基于 lastGood profile 设置 `serverHost: ''` 触发 readiness blocked）：

```dart
  testWidgets('quick retry (last good) enforces readiness preflight and blocks connect',
      (WidgetTester tester) async {
    await _setDesktopSurface(tester);

    final controller = _LastKnownGoodController(lastGoodProfileId: 'sample-hk-2');
    final services = _buildServices(controllerOverride: controller);

    final first = services.profileStore.profiles.first;
    final lastGood = services.profileStore.profiles
        .firstWhere((p) => p.id == 'sample-hk-2');

    await services.profileSecrets.saveTrojanPassword(profileId: first.id, password: 'secret-1');
    await services.profileSecrets.saveTrojanPassword(profileId: lastGood.id, password: 'secret-2');

    services.profileStore.upsertProfile(first.copyWith(hasStoredPassword: true));
    services.profileStore.upsertProfile(
      lastGood.copyWith(
        hasStoredPassword: true,
        serverHost: '',
      ),
    );

    services.profileStore.selectProfile(first.id);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProfilesPage(services: services)),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Quick Retry (Last Good)'));
    await tester.pump(const Duration(milliseconds: 360));

    expect(find.textContaining('Connect blocked:'), findsOneWidget);
    expect(find.textContaining('Next action:'), findsOneWidget);

    // Should not have attempted connect.
    expect(controller.lastConnectProfileId, isNull);
  });
```

- [ ] **步骤 2：运行测试验证失败（红灯）**

```bash
cd client
flutter test test/features/profiles/presentation/profiles_page_action_gating_test.dart
```

- [ ] **步骤 3：最少修正实现让测试通过（若需要）**

若实现已正确 preflight，此步应无需代码变更；如失败，修正 blocked 分支确保 early return。

- [ ] **步骤 4：运行测试验证通过（绿灯）**

同上命令，预期：PASS。

- [ ] **步骤 5：Commit**

```bash
cd /root/.openclaw/workspace/trojan-obfuscation
git add client/test/features/profiles/presentation/profiles_page_action_gating_test.dart
git commit -m "test(client): cover last-good quick retry readiness blocked path"
```

---

# 任务 7：最终验证与收口

- [ ] **步骤 1：按 issue #51 的证据命令跑全**

```bash
cd client
flutter test test/features/profiles/presentation/high_frequency_actions_strip_test.dart
flutter test test/features/profiles/presentation/profiles_page_action_gating_test.dart
```

预期：全部 PASS。

- [ ] **步骤 2：flutter analyze（可选但建议）**

```bash
cd client
flutter analyze
```

预期：无 error。

- [ ] **步骤 3：gh issue #51 回填证据并关单（在 PR 阶段做）**

在 PR 描述中粘贴两条测试输出（或 CI 通过链接），确认满足 acceptance criteria。

---

## 自检（writing-plans）

- 覆盖度：计划覆盖 #51 要求的 last-known-good affordance、readiness preflight、truth-safe feedback、两条指定测试证据。
- 无占位符：所有步骤提供具体代码片段、命令与预期。
- 类型一致：字段名 `lastKnownGoodProfileId`、回调名 `onQuickRetryLastGood`、文案 `Quick Retry (Last Good)` 在全计划保持一致。
