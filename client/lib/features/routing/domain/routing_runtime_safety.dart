class RoutingRollbackWindowTracker {
  RoutingRollbackWindowTracker({
    this.maxRollbacks = 2,
    this.window = const Duration(minutes: 30),
  }) : assert(maxRollbacks > 0, 'maxRollbacks must be positive');

  final int maxRollbacks;
  final Duration window;

  final Map<String, List<DateTime>> _historyByCandidate =
      <String, List<DateTime>>{};

  bool recordFailure({required String candidateKey, required DateTime at}) {
    final key = candidateKey.trim();
    if (key.isEmpty) return false;

    final history =
        _historyByCandidate.putIfAbsent(key, () => <DateTime>[]);
    history.add(at);

    final threshold = at.subtract(window);
    history.removeWhere((timestamp) => timestamp.isBefore(threshold));

    return history.length >= maxRollbacks;
  }

  void clear(String candidateKey) {
    final key = candidateKey.trim();
    if (key.isEmpty) return;
    _historyByCandidate.remove(key);
  }
}

class RoutingQuarantineRegistry {
  final Set<String> _candidateKeys = <String>{};

  bool isQuarantined(String candidateKey) {
    final key = candidateKey.trim();
    if (key.isEmpty) return false;
    return _candidateKeys.contains(key);
  }

  void quarantine(String candidateKey) {
    final key = candidateKey.trim();
    if (key.isEmpty) return;
    _candidateKeys.add(key);
  }

  void release(String candidateKey) {
    final key = candidateKey.trim();
    if (key.isEmpty) return;
    _candidateKeys.remove(key);
  }
}
