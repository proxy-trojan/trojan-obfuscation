import 'package:flutter/material.dart';

class FirstConnectGuidanceCard extends StatelessWidget {
  const FirstConnectGuidanceCard({
    super.key,
    required this.blockingReason,
    required this.nextAction,
  });

  final String? blockingReason;
  final String nextAction;

  @override
  Widget build(BuildContext context) {
    final hasBlocker = blockingReason != null && blockingReason!.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasBlocker
            ? Colors.orange.withValues(alpha: 0.08)
            : Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasBlocker
              ? Colors.orange.withValues(alpha: 0.25)
              : Colors.green.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            hasBlocker
                ? 'Connect blocker: $blockingReason'
                : 'Ready for first connect',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text('Next step: $nextAction'),
        ],
      ),
    );
  }
}
