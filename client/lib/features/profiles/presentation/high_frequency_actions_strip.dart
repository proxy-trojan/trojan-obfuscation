import 'package:flutter/material.dart';

class HighFrequencyActionsStrip extends StatelessWidget {
  const HighFrequencyActionsStrip({
    super.key,
    this.enabled = true,
    required this.onQuickConnect,
    required this.onQuickDisconnect,
    required this.onSwitchProfile,
    this.onQuickRetryLastGood,
  });

  final bool enabled;
  final VoidCallback? onQuickConnect;
  final VoidCallback? onQuickDisconnect;
  final VoidCallback? onSwitchProfile;
  final VoidCallback? onQuickRetryLastGood;

  @override
  Widget build(BuildContext context) {
    final connectHandler = enabled ? onQuickConnect : null;
    final disconnectHandler = enabled ? onQuickDisconnect : null;
    final retryHandler = enabled ? onQuickRetryLastGood : null;
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
        if (onQuickRetryLastGood != null)
          OutlinedButton(
            onPressed: retryHandler,
            child: const Text('Quick Retry (Last Good)'),
          ),
        TextButton(
          onPressed: switchHandler,
          child: const Text('Switch Profile'),
        ),
      ],
    );
  }
}
