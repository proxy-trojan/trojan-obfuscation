import '../domain/routing_probe_models.dart';

const List<RoutingProbeScenario> routingProbeCoreScenarios =
    <RoutingProbeScenario>[
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
