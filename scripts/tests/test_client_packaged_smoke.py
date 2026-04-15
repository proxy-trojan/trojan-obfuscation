import os
import tarfile
import tempfile
import unittest
from unittest import mock
import zipfile
from pathlib import Path

from scripts.client_packaged_smoke import (
    PackagedArtifactNotFound,
    extract_packaged_artifact,
    resolve_packaged_artifact,
    resolve_packaged_executable,
    run_packaged_executable_smoke,
)


class ClientPackagedSmokeTest(unittest.TestCase):
    def test_resolves_linux_bundle_executable(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            binary = root / 'trojan_pro_client'
            binary.write_text('')
            binary.chmod(0o755)

            self.assertEqual(resolve_packaged_executable('linux', root), binary)

    def test_resolves_linux_packaged_artifact(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            artifact = root / 'trojan-pro-client_1.4.0_linux-x64-bundle.tar.gz'
            artifact.write_text('')

            self.assertEqual(resolve_packaged_artifact('linux', root), artifact)

    def test_resolves_windows_packaged_executable(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            binary = root / 'Trojan Pro Client.exe'
            binary.write_text('')

            self.assertEqual(resolve_packaged_executable('windows', root), binary)

    def test_resolves_windows_packaged_artifact(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            artifact = root / 'trojan-pro-client_1.4.0_windows-x64.zip'
            artifact.write_text('')

            self.assertEqual(resolve_packaged_artifact('windows', root), artifact)

    def test_resolves_macos_app_binary(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            binary = root / 'Trojan Pro Client.app' / 'Contents' / 'MacOS' / 'Trojan Pro Client'
            binary.parent.mkdir(parents=True)
            binary.write_text('')
            binary.chmod(0o755)

            self.assertEqual(resolve_packaged_executable('macos', root), binary)

    def test_resolves_macos_packaged_artifact(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            artifact = root / 'trojan-pro-client_1.4.0_macos-app.zip'
            artifact.write_text('')

            self.assertEqual(resolve_packaged_artifact('macos', root), artifact)

    def test_extracts_linux_bundle_artifact(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            bundle_dir = root / 'trojan-pro-client'
            bundle_dir.mkdir()
            binary = bundle_dir / 'trojan_pro_client'
            binary.write_text('')
            binary.chmod(0o755)
            artifact = root / 'trojan-pro-client_1.4.0_linux-x64-bundle.tar.gz'
            with tarfile.open(artifact, 'w:gz') as archive:
                archive.add(bundle_dir, arcname=bundle_dir.name)

            extracted_root = root / 'out-linux'
            extract_packaged_artifact('linux', artifact, extracted_root)

            self.assertEqual(
                resolve_packaged_executable('linux', extracted_root),
                extracted_root / 'trojan-pro-client' / 'trojan_pro_client',
            )

    def test_extracts_windows_zip_artifact(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            artifact = root / 'trojan-pro-client_1.4.0_windows-x64.zip'
            with zipfile.ZipFile(artifact, 'w') as archive:
                archive.writestr('Trojan Pro Client.exe', '')

            extracted_root = root / 'out-windows'
            extract_packaged_artifact('windows', artifact, extracted_root)

            self.assertEqual(
                resolve_packaged_executable('windows', extracted_root),
                extracted_root / 'Trojan Pro Client.exe',
            )

    def test_extracts_macos_zip_artifact(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            artifact = root / 'trojan-pro-client_1.4.0_macos-app.zip'
            with zipfile.ZipFile(artifact, 'w') as archive:
                info = zipfile.ZipInfo(
                    'Trojan Pro Client.app/Contents/MacOS/Trojan Pro Client',
                )
                info.external_attr = 0o755 << 16
                archive.writestr(info, '')

            extracted_root = root / 'out-macos'
            extract_packaged_artifact('macos', artifact, extracted_root)

            executable = resolve_packaged_executable('macos', extracted_root)
            self.assertEqual(
                executable,
                extracted_root
                / 'Trojan Pro Client.app'
                / 'Contents'
                / 'MacOS'
                / 'Trojan Pro Client',
            )
            self.assertTrue(os.access(executable, os.X_OK))

    def test_extracts_macos_zip_symlinks(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            artifact = root / 'trojan-pro-client_1.4.0_macos-app.zip'
            link_path = 'trojan_pro_client.app/Contents/Frameworks/App.framework/Versions/Current'
            with zipfile.ZipFile(artifact, 'w') as archive:
                app_binary = zipfile.ZipInfo(
                    'trojan_pro_client.app/Contents/MacOS/trojan_pro_client',
                )
                app_binary.external_attr = 0o755 << 16
                archive.writestr(app_binary, '')

                framework_binary = zipfile.ZipInfo(
                    'trojan_pro_client.app/Contents/Frameworks/App.framework/Versions/A/App',
                )
                framework_binary.external_attr = 0o755 << 16
                archive.writestr(framework_binary, '')

                symlink = zipfile.ZipInfo(link_path)
                symlink.create_system = 3
                symlink.external_attr = 0o120777 << 16
                archive.writestr(symlink, 'A')

            extracted_root = root / 'out-macos'
            extract_packaged_artifact('macos', artifact, extracted_root)

            current_link = extracted_root / link_path
            self.assertTrue(current_link.is_symlink())
            self.assertEqual(os.readlink(current_link), 'A')

    def test_runs_linux_packaged_executable_smoke(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            binary = root / 'trojan_pro_client'
            binary.write_text('#!/usr/bin/env python3\nimport time\ntime.sleep(2)\n')
            binary.chmod(0o755)
            log_path = root / 'linux-smoke.log'

            result = run_packaged_executable_smoke(
                'linux',
                binary,
                smoke_window_seconds=1,
                log_path=log_path,
                environment={'DISPLAY': ':99'},
            )

            self.assertTrue(result.passed)
            self.assertIn('stayed alive', result.summary)

    def test_marks_linux_packaged_smoke_as_skipped_when_headless(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            binary = root / 'trojan_pro_client'
            binary.write_text('#!/usr/bin/env python3\nimport time\ntime.sleep(2)\n')
            binary.chmod(0o755)
            log_path = root / 'linux-smoke.log'

            with mock.patch('scripts.client_packaged_smoke.shutil.which', return_value=None):
                result = run_packaged_executable_smoke(
                    'linux',
                    binary,
                    smoke_window_seconds=1,
                    log_path=log_path,
                    environment={'DISPLAY': '', 'WAYLAND_DISPLAY': ''},
                )

            self.assertFalse(result.passed)
            self.assertTrue(result.skipped)
            self.assertIn('requires DISPLAY', result.summary)

    def test_injects_single_instance_lock_name_for_smoke_launch(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            binary = root / 'trojan_pro_client'
            binary.write_text('')
            binary.chmod(0o755)
            log_path = root / 'linux-smoke.log'

            fake_process = mock.Mock()
            fake_process.poll.return_value = 0

            with mock.patch(
                'scripts.client_packaged_smoke.subprocess.Popen',
                return_value=fake_process,
            ) as popen:
                result = run_packaged_executable_smoke(
                    'linux',
                    binary,
                    smoke_window_seconds=0,
                    log_path=log_path,
                    environment={'DISPLAY': ':99'},
                )

            self.assertTrue(result.passed)
            launch_env = popen.call_args.kwargs['env']
            lock_name = launch_env.get('TROJAN_CLIENT_SINGLE_INSTANCE_LOCK_NAME')
            self.assertIsNotNone(lock_name)
            self.assertIn('packaged_smoke.linux', lock_name)

    def test_overrides_inherited_single_instance_lock_name_for_smoke_launch(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            binary = root / 'trojan_pro_client'
            binary.write_text('')
            binary.chmod(0o755)
            log_path = root / 'linux-smoke.log'

            fake_process = mock.Mock()
            fake_process.poll.return_value = 0

            with mock.patch.dict(
                os.environ,
                {'TROJAN_CLIENT_SINGLE_INSTANCE_LOCK_NAME': 'sticky.lock'},
                clear=False,
            ):
                with mock.patch(
                    'scripts.client_packaged_smoke.subprocess.Popen',
                    return_value=fake_process,
                ) as popen:
                    result = run_packaged_executable_smoke(
                        'linux',
                        binary,
                        smoke_window_seconds=0,
                        log_path=log_path,
                        environment={'DISPLAY': ':99'},
                    )

            self.assertTrue(result.passed)
            launch_env = popen.call_args.kwargs['env']
            lock_name = launch_env.get('TROJAN_CLIENT_SINGLE_INSTANCE_LOCK_NAME')
            self.assertIsNotNone(lock_name)
            self.assertIn('packaged_smoke.linux', lock_name)
            self.assertNotEqual(lock_name, 'sticky.lock')

    def test_captures_log_tail_when_packaged_executable_exits_early(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            binary = root / 'Trojan Pro Client.exe'
            binary.write_text(
                '#!/usr/bin/env python3\n'
                'print("line-1")\n'
                'print("line-2")\n'
            )
            binary.chmod(0o755)
            log_path = root / 'windows-smoke.log'

            result = run_packaged_executable_smoke(
                'windows',
                binary,
                smoke_window_seconds=1,
                log_path=log_path,
            )

            self.assertFalse(result.passed)
            self.assertEqual(result.exit_code, 0)
            self.assertIn('exited early with code 0', result.summary)
            self.assertEqual(result.log_tail, ('line-1', 'line-2'))

    def test_raises_when_packaged_artifact_is_missing(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)

            with self.assertRaises(PackagedArtifactNotFound):
                resolve_packaged_artifact('linux', root)


if __name__ == '__main__':
    unittest.main()
