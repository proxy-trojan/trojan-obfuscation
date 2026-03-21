import 'package:flutter/widgets.dart';

import '../domain/readiness_report.dart';

typedef ReadinessReportRestorer = Future<ReadinessReport?> Function();
typedef ReadinessReportBuilder = Future<ReadinessReport> Function();

class ReadinessSurfaceController {
  ReadinessSurfaceController({
    required bool Function() isMounted,
    required StateSetter applyState,
  })  : _isMounted = isMounted,
        _applyState = applyState;

  final bool Function() _isMounted;
  final StateSetter _applyState;

  Future<ReadinessReport>? _future;
  ReadinessReport? _latestReport;
  String? _lastRefreshKey;
  int _requestToken = 0;
  int _lastAppliedLiveToken = -1;

  Future<ReadinessReport>? get future => _future;
  ReadinessReport? get latestReport => _latestReport;

  void replaceLatestReport(ReadinessReport report) {
    _setState(() {
      _latestReport = report;
    });
  }

  void initialize({
    required String refreshKey,
    required ReadinessReportRestorer restoreReport,
    required ReadinessReportBuilder buildReport,
  }) {
    _lastRefreshKey = refreshKey;
    startCycle(
      restoreReport: restoreReport,
      buildReport: buildReport,
    );
  }

  void refreshIfKeyChanged(
    String refreshKey, {
    required ReadinessReportRestorer restoreReport,
    required ReadinessReportBuilder buildReport,
  }) {
    if (_lastRefreshKey == refreshKey) return;
    _lastRefreshKey = refreshKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isMounted()) return;
      startCycle(
        restoreReport: restoreReport,
        buildReport: buildReport,
      );
    });
  }

  void startCycle({
    required ReadinessReportRestorer restoreReport,
    required ReadinessReportBuilder buildReport,
  }) {
    _requestToken++;
    final requestToken = _requestToken;
    _restoreLastKnownReadiness(
      requestToken: requestToken,
      restoreReport: restoreReport,
    );
    _refreshReadiness(
      requestToken: requestToken,
      buildReport: buildReport,
    );
  }

  void _restoreLastKnownReadiness({
    required int requestToken,
    required ReadinessReportRestorer restoreReport,
  }) {
    restoreReport().then((report) {
      if (!_isMounted() || report == null) return;
      if (requestToken != _requestToken) return;
      if (_lastAppliedLiveToken == requestToken) return;
      _setState(() {
        _latestReport = report;
      });
    });
  }

  void _refreshReadiness({
    required int requestToken,
    required ReadinessReportBuilder buildReport,
  }) {
    final future = buildReport();
    _setState(() {
      _future = future;
    });
    future.then((report) {
      if (!_isMounted()) return;
      if (requestToken != _requestToken) return;
      if (!identical(_future, future)) return;
      _setState(() {
        _lastAppliedLiveToken = requestToken;
        _latestReport = report;
      });
    });
  }

  void _setState(VoidCallback fn) {
    if (!_isMounted()) return;
    _applyState(fn);
  }
}
