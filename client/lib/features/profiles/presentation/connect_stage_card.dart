import 'package:flutter/material.dart';

import '../../../core/widgets/section_card.dart';
import '../../controller/domain/client_connection_status.dart';
import '../domain/client_profile.dart';

class ConnectStageCard extends StatelessWidget {
  const ConnectStageCard({
    super.key,
    required this.profile,
    required this.status,
    required this.active,
    required this.runtimeMode,
    required this.onConnectToggle,
    required this.onManagePassword,
  });

  final ClientProfile profile;
  final ClientConnectionStatus status;
  final bool active;
  final String runtimeMode;
  final VoidCallback? onConnectToggle;
  final VoidCallback onManagePassword;

  @override
  Widget build(BuildContext context) {
    final connectionLabel = switch (status.phase) {
      ClientConnectionPhase.disconnected => 'Disconnected',
      ClientConnectionPhase.connecting => 'Connecting',
      ClientConnectionPhase.connected => 'Connected',
      ClientConnectionPhase.error => 'Needs attention',
    };

    final readiness = !profile.hasStoredPassword
        ? 'Password missing'
        : status.phase == ClientConnectionPhase.error
            ? 'Check before retry'
            : status.phase == ClientConnectionPhase.connected
                ? 'Connected'
                : 'Ready to test';

    final readinessColor = !profile.hasStoredPassword
        ? Colors.orange
        : status.phase == ClientConnectionPhase.error
            ? Colors.red
            : status.phase == ClientConnectionPhase.connected
                ? Colors.green
                : Colors.blue;

    final hint = !profile.hasStoredPassword
        ? 'Save the password first so this profile is ready for one clean test.'
        : status.phase == ClientConnectionPhase.connected
            ? 'You are already connected with this profile.'
            : status.phase == ClientConnectionPhase.connecting
                ? 'A connection attempt is already running.'
                : status.phase == ClientConnectionPhase.error
                    ? 'Something went wrong last time. You can retry or open Troubleshooting.'
                    : 'This profile is ready. Use one clear Connect button when you want to test it.';

    return SectionCard(
      title: profile.name,
      subtitle: '${profile.serverHost}:${profile.serverPort}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: readinessColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: readinessColor.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Wrap(
                        spacing: 24,
                        runSpacing: 12,
                        children: <Widget>[
                          _kv('Ready', readiness),
                          _kv('Connection', active && status.phase == ClientConnectionPhase.connected ? 'Connected' : connectionLabel),
                          _kv('Password', profile.hasStoredPassword ? 'Ready' : 'Missing'),
                          _kv('SOCKS', '127.0.0.1:${profile.localSocksPort}'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _StatusPill(label: readiness, color: readinessColor),
                  ],
                ),
                const SizedBox(height: 12),
                Text(hint),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    SizedBox(
                      height: 46,
                      child: FilledButton(
                        onPressed: onConnectToggle,
                        child: Text(
                          active && status.phase == ClientConnectionPhase.connected
                              ? 'Disconnect'
                              : 'Connect Now',
                        ),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: onManagePassword,
                      child: Text(profile.hasStoredPassword ? 'Manage Password' : 'Set Password'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Advanced connection details are available below when you need them.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _kv(String label, String value) {
    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
