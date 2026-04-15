import tempfile
import textwrap
import unittest
from pathlib import Path

from scripts.validate_client_release_truth import (
    ReleaseTruthMismatch,
    parse_pubspec_version_label,
    parse_release_metadata_label,
    parse_update_workflow_state_label,
    validate_release_truth,
)


class ReleaseTruthValidationTest(unittest.TestCase):
    def test_parses_labels_from_three_sources(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            pubspec = root / 'pubspec.yaml'
            metadata = root / 'release-metadata.env'
            workflow_state = root / 'update_workflow_state.dart'

            pubspec.write_text('version: 1.4.0+1\n')
            metadata.write_text('VERSION_LABEL="1.4.0"\n')
            workflow_state.write_text(textwrap.dedent('''
                static const UpdateWorkflowState initial = UpdateWorkflowState(
                  currentVersionLabel: '1.4.0',
                );
            '''))

            self.assertEqual(parse_pubspec_version_label(pubspec), '1.4.0')
            self.assertEqual(parse_release_metadata_label(metadata), '1.4.0')
            self.assertEqual(
                parse_update_workflow_state_label(workflow_state),
                '1.4.0',
            )

    def test_rejects_mismatched_release_truth(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            pubspec = root / 'pubspec.yaml'
            metadata = root / 'release-metadata.env'
            workflow_state = root / 'update_workflow_state.dart'

            pubspec.write_text('version: 1.4.0+1\n')
            metadata.write_text('VERSION_LABEL="1.3.9"\n')
            workflow_state.write_text("currentVersionLabel: '1.4.0',\n")

            with self.assertRaises(ReleaseTruthMismatch) as ctx:
                validate_release_truth(
                    pubspec_path=pubspec,
                    metadata_path=metadata,
                    workflow_state_path=workflow_state,
                )

            self.assertIn('release truth mismatch', str(ctx.exception))
            self.assertIn('packaging', str(ctx.exception))


if __name__ == '__main__':
    unittest.main()
