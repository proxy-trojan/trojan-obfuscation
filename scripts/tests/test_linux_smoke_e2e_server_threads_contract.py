from pathlib import Path
import re

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT_PATH = REPO_ROOT / "tests" / "LinuxSmokeTest" / "e2e-deploy-test.sh"


def test_linux_smoke_e2e_server_has_multi_thread_capacity_for_concurrency_case() -> None:
    text = SCRIPT_PATH.read_text(encoding="utf-8")

    assert "Test 4: 并发连接稳定性测试 (5 个并发请求)" in text

    match = re.search(r'"threads":\s*(\d+),', text)
    assert match is not None
    assert int(match.group(1)) >= 4
