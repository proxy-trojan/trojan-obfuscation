import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/controller/domain/controller_runtime_session.dart';

import '../../../testing/runtime_truth_expectations.dart';

void main() {
  for (final truth in iter3TruthStates) {
    test('truth expectations stay consistent for ${truth.name}', () {
      final session = buildSessionForTruth(truth);
      final expectation = runtimeTruthExpectationFor(truth);

      expect(session.truth, truth);
      expect(session.truth.label, expectation.label);
      expect(session.needsAttention, expectation.needsAttention);

      for (final token in expectation.truthNoteContains) {
        expect(session.truthNote, contains(token));
      }
      for (final token in expectation.recoveryGuidanceContains) {
        expect(session.recoveryGuidance, contains(token));
      }
    });
  }
}
