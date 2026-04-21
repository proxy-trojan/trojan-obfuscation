import 'package:flutter/material.dart';

class HighFrequencyActionsStrip extends StatelessWidget {
  const HighFrequencyActionsStrip({
    super.key,
    this.enabled = true,
    required this.onQuickConnect,
    required this.onQuickDisconnect,
    required this.onSwitchProfile,
  });

  final bool enabled;
  final VoidCallback? onQuickConnect;
  final VoidCallback? onQuickDisconnect;
  final VoidCallback? onSwitchProfile;

  @override
  Widget build(BuildContext context) {
    final connectHandler = enabled ? onQuickConnect : null;
    final disconnectHandler = enabled ? onQuickDisconnect : null;
    final switchHandler = enabled ? onSwitchProfile : null;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        FilledButton(
          onPressed: connectHandler,
          child: const Text('Quick Connect'),
        ),
        OutlinedButton(
          onPressed: disconnectHandler,
          child: const Text('Quick Disconnect'),
        ),
        TextButton(
          onPressed: switchHandler,
          child: const Text('Switch Profile'),
        ),
      ],
    );
  }
}
