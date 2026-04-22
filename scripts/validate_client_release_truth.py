#!/usr/bin/env python3
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import argparse
import re
import sys


class ReleaseTruthMismatch(RuntimeError):
    pass


@dataclass(frozen=True)
class ReleaseTruthSnapshot:
    pubspec: str
    packaging: str
    workflow_state: str


def _extract(pattern: str, text: str, source: Path, label: str) -> str:
    match = re.search(pattern, text, re.MULTILINE)
    if not match:
        raise ReleaseTruthMismatch(f'could not parse {label} from {source}')
    return match.group(1).strip()


def parse_pubspec_version_label(pubspec_path: Path) -> str:
    text = pubspec_path.read_text()
    version = _extract(r'^version:\s*([^\s]+)\s*$', text, pubspec_path, 'pubspec version')
    return version.split('+', 1)[0]


def parse_release_metadata_label(metadata_path: Path) -> str:
    text = metadata_path.read_text()
    return _extract(r'^VERSION_LABEL="([^"]+)"\s*$', text, metadata_path, 'packaging version label')


def parse_update_workflow_state_label(workflow_state_path: Path) -> str:
    text = workflow_state_path.read_text()
    return _extract(r"currentVersionLabel:\s*'([^']+)'", text, workflow_state_path, 'workflow state version label')


def collect_release_truth(pubspec_path: Path, metadata_path: Path, workflow_state_path: Path) -> ReleaseTruthSnapshot:
    return ReleaseTruthSnapshot(
        pubspec=parse_pubspec_version_label(pubspec_path),
        packaging=parse_release_metadata_label(metadata_path),
        workflow_state=parse_update_workflow_state_label(workflow_state_path),
    )


def validate_release_truth(*, pubspec_path: Path, metadata_path: Path, workflow_state_path: Path) -> ReleaseTruthSnapshot:
    snapshot = collect_release_truth(pubspec_path, metadata_path, workflow_state_path)
    labels = {snapshot.pubspec, snapshot.packaging, snapshot.workflow_state}
    if len(labels) != 1:
        raise ReleaseTruthMismatch(
            'release truth mismatch: '
            f'pubspec={snapshot.pubspec}, packaging={snapshot.packaging}, workflow_state={snapshot.workflow_state}'
        )
    return snapshot


def main() -> int:
    parser = argparse.ArgumentParser(description='Validate Trojan-Pro client release truth across code and packaging metadata.')
    parser.add_argument('--pubspec', type=Path, default=Path('client/pubspec.yaml'))
    parser.add_argument('--metadata', type=Path, default=Path('packaging/linux/release-metadata.env'))
    parser.add_argument(
        '--workflow-state',
        type=Path,
        default=Path('client/lib/features/packaging/domain/update_workflow_state.dart'),
    )
    args = parser.parse_args()

    try:
        snapshot = validate_release_truth(
            pubspec_path=args.pubspec,
            metadata_path=args.metadata,
            workflow_state_path=args.workflow_state,
        )
    except ReleaseTruthMismatch as exc:
        print(str(exc), file=sys.stderr)
        return 1

    print('release truth summary')
    print(f'- version label: {snapshot.pubspec}')
    print('- sources: pubspec / packaging metadata / workflow state aligned')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
