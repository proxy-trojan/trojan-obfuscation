#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import shutil
import stat
import subprocess
import sys
import tarfile
import tempfile
import time
import zipfile
from dataclasses import dataclass
from pathlib import Path


class PackagedArtifactNotFound(FileNotFoundError):
    pass


class PackagedExecutableNotFound(FileNotFoundError):
    pass


class PackagedSmokeSkipped(RuntimeError):
    pass


@dataclass(frozen=True)
class PackagedSmokeResult:
    passed: bool
    summary: str
    skipped: bool = False
    exit_code: int | None = None
    command: tuple[str, ...] = ()


_ARTIFACT_PATTERNS = {
    'linux': 'trojan-pro-client_*_linux-x64-bundle.tar.gz',
    'windows': 'trojan-pro-client_*_windows-x64.zip',
    'macos': 'trojan-pro-client_*_macos-app.zip',
}

_EXECUTABLE_BASENAME = 'trojan_pro_client'
_WINDOWS_EXECUTABLE_BASENAME = 'trojan_pro_client.exe'
_MACOS_APP_NAME = 'trojan_pro_client.app'


def _normalize_platform(platform: str) -> str:
    platform_key = platform.strip().lower()
    if platform_key not in _ARTIFACT_PATTERNS:
        raise ValueError(f'unsupported packaged smoke platform: {platform}')
    return platform_key


def resolve_packaged_artifact(platform: str, root: Path) -> Path:
    platform_key = _normalize_platform(platform)
    root = Path(root)
    matches = sorted(root.glob(_ARTIFACT_PATTERNS[platform_key]))
    if matches:
        return matches[0]
    raise PackagedArtifactNotFound(
        f'missing packaged artifact for {platform_key} under {root}'
    )


def extract_packaged_artifact(platform: str, artifact_path: Path, extract_root: Path) -> Path:
    platform_key = _normalize_platform(platform)
    artifact_path = Path(artifact_path)
    extract_root = Path(extract_root)

    if extract_root.exists():
        shutil.rmtree(extract_root)
    extract_root.mkdir(parents=True, exist_ok=True)

    if platform_key == 'linux':
        with tarfile.open(artifact_path, 'r:*') as archive:
            archive.extractall(extract_root)
        return extract_root

    with zipfile.ZipFile(artifact_path) as archive:
        for info in archive.infolist():
            _extract_zip_member(archive, info, extract_root)
    return extract_root


def resolve_packaged_executable(platform: str, root: Path) -> Path:
    platform_key = _normalize_platform(platform)
    root = Path(root)

    if platform_key == 'linux':
        preferred = list(_sorted_files(root.rglob(_EXECUTABLE_BASENAME)))
        if preferred:
            return preferred[0]
        raise PackagedExecutableNotFound(
            f'missing Linux packaged executable under {root}'
        )

    if platform_key == 'windows':
        preferred = list(_sorted_files(root.rglob(_WINDOWS_EXECUTABLE_BASENAME)))
        if preferred:
            return preferred[0]
        fallback = list(_sorted_files(root.rglob('*.exe')))
        if fallback:
            return fallback[0]
        raise PackagedExecutableNotFound(
            f'missing Windows packaged executable under {root}'
        )

    preferred = root / _MACOS_APP_NAME / 'Contents' / 'MacOS' / _EXECUTABLE_BASENAME
    if preferred.is_file():
        return preferred
    fallback = list(_sorted_files(root.rglob('*.app/Contents/MacOS/*')))
    if fallback:
        return fallback[0]
    raise PackagedExecutableNotFound(f'missing macOS packaged executable under {root}')


def run_packaged_executable_smoke(
    platform: str,
    executable: Path,
    *,
    smoke_window_seconds: int = 8,
    log_path: Path | None = None,
    environment: dict[str, str] | None = None,
) -> PackagedSmokeResult:
    platform_key = _normalize_platform(platform)
    executable = Path(executable)
    if not executable.is_file():
        raise PackagedExecutableNotFound(f'packaged executable does not exist: {executable}')

    env = os.environ.copy()
    if environment:
        env.update(environment)
    env.setdefault('TROJAN_CLIENT_BACKEND_MODE', 'stub')
    env.setdefault('TROJAN_CLIENT_ENABLE_REAL_ADAPTER', '0')

    command: list[str] = []
    resolved_log_path = Path(log_path) if log_path is not None else executable.parent / 'packaged-smoke.log'
    resolved_log_path.parent.mkdir(parents=True, exist_ok=True)

    try:
        command = _build_launch_command(platform_key, executable, env)
        with resolved_log_path.open('w', encoding='utf-8') as log_file:
            process = subprocess.Popen(
                command,
                stdout=log_file,
                stderr=subprocess.STDOUT,
                env=env,
            )
            deadline = time.monotonic() + smoke_window_seconds
            while time.monotonic() < deadline:
                exit_code = process.poll()
                if exit_code is not None:
                    return PackagedSmokeResult(
                        passed=False,
                        summary=f'packaged executable exited early with code {exit_code}',
                        exit_code=exit_code,
                        command=tuple(command),
                    )
                time.sleep(0.2)
            _terminate_process(process)
    except PackagedSmokeSkipped as exc:
        return PackagedSmokeResult(
            passed=False,
            skipped=True,
            summary=str(exc),
            command=tuple(command),
        )
    except OSError as exc:
        return PackagedSmokeResult(
            passed=False,
            summary=f'failed to launch packaged executable: {exc}',
            command=tuple(command),
        )

    return PackagedSmokeResult(
        passed=True,
        summary=f'packaged executable stayed alive for {smoke_window_seconds}s smoke window',
        command=tuple(command),
    )


def _extract_zip_member(
    archive: zipfile.ZipFile,
    info: zipfile.ZipInfo,
    extract_root: Path,
) -> None:
    target = extract_root / info.filename
    if info.is_dir():
        target.mkdir(parents=True, exist_ok=True)
        return

    mode = info.external_attr >> 16
    if stat.S_ISLNK(mode):
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.exists() or target.is_symlink():
            if target.is_dir() and not target.is_symlink():
                shutil.rmtree(target)
            else:
                target.unlink()
        link_target = archive.read(info).decode('utf-8')
        os.symlink(link_target, target)
        return

    archive.extract(info, extract_root)
    _restore_zip_permissions(info, target)


def _restore_zip_permissions(info: zipfile.ZipInfo, target: Path) -> None:
    mode = info.external_attr >> 16
    if mode and target.exists() and not target.is_dir() and not target.is_symlink():
        target.chmod(mode)



def _sorted_files(paths: object) -> list[Path]:
    return sorted(path for path in paths if isinstance(path, Path) and path.is_file())


def _build_launch_command(platform: str, executable: Path, env: dict[str, str]) -> list[str]:
    if platform == 'linux':
        if env.get('DISPLAY') or env.get('WAYLAND_DISPLAY'):
            return [str(executable)]
        xvfb = shutil.which('xvfb-run')
        if xvfb:
            return [xvfb, '-a', str(executable)]
        raise PackagedSmokeSkipped(
            'linux packaged smoke requires DISPLAY/WAYLAND_DISPLAY or xvfb-run'
        )

    return [str(executable)]


def _terminate_process(process: subprocess.Popen[bytes] | subprocess.Popen[str]) -> None:
    if process.poll() is not None:
        return

    process.terminate()
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=5)


def main() -> int:
    parser = argparse.ArgumentParser(
        description='Resolve, extract, and smoke-check Trojan-Pro client packaged artifacts.'
    )
    parser.add_argument('--platform', required=True, choices=['linux', 'windows', 'macos'])
    parser.add_argument('--artifact-root', type=Path, required=True)
    parser.add_argument('--extract-root', type=Path)
    parser.add_argument(
        '--mode',
        choices=['artifact', 'extract', 'executable', 'smoke'],
        default='artifact',
    )
    parser.add_argument('--smoke-window-seconds', type=int, default=8)
    parser.add_argument('--allow-skip', action='store_true')
    args = parser.parse_args()

    temp_dir: tempfile.TemporaryDirectory[str] | None = None
    try:
        artifact = resolve_packaged_artifact(args.platform, args.artifact_root)

        if args.mode == 'artifact':
            print(artifact)
            return 0

        extract_root = args.extract_root
        if extract_root is None:
            temp_dir = tempfile.TemporaryDirectory(prefix='client-packaged-smoke-')
            extract_root = Path(temp_dir.name)

        extracted_root = extract_packaged_artifact(args.platform, artifact, extract_root)

        if args.mode == 'extract':
            print(extracted_root)
            return 0

        executable = resolve_packaged_executable(args.platform, extracted_root)
        if args.mode == 'executable':
            print(executable)
            return 0

        result = run_packaged_executable_smoke(
            args.platform,
            executable,
            smoke_window_seconds=args.smoke_window_seconds,
            log_path=extracted_root / 'packaged-smoke.log',
        )
        print('packaged smoke summary')
        print(f'- platform: {args.platform}')
        print(f'- artifact: {artifact}')
        print(f'- extracted root: {extracted_root}')
        print(f'- executable: {executable}')
        print(f'- result: {result.summary}')
        if result.command:
            print(f"- command: {' '.join(result.command)}")
        if result.passed:
            return 0
        if result.skipped and args.allow_skip:
            return 0
        return 1
    except (PackagedArtifactNotFound, PackagedExecutableNotFound, ValueError) as exc:
        print(str(exc), file=sys.stderr)
        return 1
    finally:
        if temp_dir is not None:
            temp_dir.cleanup()


if __name__ == '__main__':
    raise SystemExit(main())
