import 'package:flutter/material.dart';

import '../../../core/widgets/section_card.dart';
import '../../controller/domain/client_connection_status.dart';
import '../../controller/domain/controller_runtime_session.dart';
import '../../controller/domain/failure_family.dart';
import 'next_action_policy.dart';

class ConnectTimelineCard extends StatelessWidget {
  const ConnectTimelineCard({
    super.key,
    required this.status,
    required this.runtimeSession,
    required this.failureFamily,
    required this.nextAction,
  });

  final ClientConnectionStatus status;
  final ControllerRuntimeSession runtimeSession;
  final FailureFamily failureFamily;
  final ProfileNextActionDecision nextAction;

  static const List<_ConnectTimelineStage> _stages = <_ConnectTimelineStage>[
    _ConnectTimelineStage(
      key: 'planned',
      description: 'Build and validate managed runtime launch inputs.',
    ),
    _ConnectTimelineStage(
      key: 'launching',
      description: 'Start runtime process and watch early bootstrap signals.',
    ),
    _ConnectTimelineStage(
      key: 'alive',
      description: 'Runtime process is alive and emits runtime evidence.',
    ),
    _ConnectTimelineStage(
      key: 'session-ready',
      description: 'Runtime-true session-ready reached. Connect is trustworthy.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final stageIndex = _stageIndex(status: status, runtimeSession: runtimeSession);
    final currentStageLabel =
        stageIndex == null ? 'idle' : _stages[stageIndex].key;

    return SectionCard(
      title: 'Connect timeline',
      subtitle: 'Runtime phase progression for first-connect transparency.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Current stage: $currentStageLabel',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ..._stages.asMap().entries.map((entry) {
            final index = entry.key;
            final stage = entry.value;
            final state = _stateFor(index: index, currentStageIndex: stageIndex);
            return _buildStageRow(context, stage, state);
          }),
          if (_showExitConfirmationWarning(status, runtimeSession)) ...<Widget>[
            const SizedBox(height: 8),
            const Text(
              'Waiting for exit confirmation before marking disconnected.',
              style: TextStyle(
                color: Colors.deepOrange,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (status.phase == ClientConnectionPhase.error) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'Failure family: ${failureFamily.displayLabel}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (nextAction.isActionable) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                'Next action: ${nextAction.label}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(nextAction.detail),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildStageRow(
    BuildContext context,
    _ConnectTimelineStage stage,
    _ConnectTimelineStageState state,
  ) {
    final palette = switch (state) {
      _ConnectTimelineStageState.completed => (
          icon: Icons.check_circle,
          color: Colors.green,
          tag: 'completed',
        ),
      _ConnectTimelineStageState.active => (
          icon: Icons.play_circle_fill,
          color: Colors.blue,
          tag: 'active',
        ),
      _ConnectTimelineStageState.pending => (
          icon: Icons.radio_button_unchecked,
          color: Colors.grey,
          tag: 'pending',
        ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            palette.icon,
            size: 18,
            color: palette.color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${stage.key} • ${palette.tag}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: palette.color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  stage.description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _ConnectTimelineStageState _stateFor({
    required int index,
    required int? currentStageIndex,
  }) {
    if (currentStageIndex == null) {
      return _ConnectTimelineStageState.pending;
    }
    if (index < currentStageIndex) {
      return _ConnectTimelineStageState.completed;
    }
    if (index == currentStageIndex) {
      return _ConnectTimelineStageState.active;
    }
    return _ConnectTimelineStageState.pending;
  }

  int? _stageIndex({
    required ClientConnectionStatus status,
    required ControllerRuntimeSession runtimeSession,
  }) {
    if (status.phase == ClientConnectionPhase.disconnected &&
        !runtimeSession.isRunning) {
      return null;
    }

    return switch (runtimeSession.phase) {
      ControllerRuntimePhase.planned => 0,
      ControllerRuntimePhase.launching => 1,
      ControllerRuntimePhase.alive => 2,
      ControllerRuntimePhase.sessionReady => 3,
      ControllerRuntimePhase.failed => 2,
      ControllerRuntimePhase.stopped =>
        status.phase == ClientConnectionPhase.connected ? 3 : null,
    };
  }

  bool _showExitConfirmationWarning(
    ClientConnectionStatus status,
    ControllerRuntimeSession runtimeSession,
  ) {
    return status.phase == ClientConnectionPhase.disconnecting ||
        runtimeSession.truth == ControllerRuntimeSessionTruth.stopping;
  }
}

enum _ConnectTimelineStageState {
  completed,
  active,
  pending,
}

class _ConnectTimelineStage {
  const _ConnectTimelineStage({
    required this.key,
    required this.description,
  });

  final String key;
  final String description;
}
