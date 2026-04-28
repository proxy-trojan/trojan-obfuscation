import os
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
CLI_PATH = REPO_ROOT / "scripts" / "install" / "runtime" / "cli.py"


def test_tp_install_prompts_for_language_when_lang_missing(tmp_path: Path) -> None:
    # In interactive mode (no --non-interactive) and no --lang, it should prompt for language.
    proc = subprocess.run(
        [sys.executable, str(CLI_PATH), "--root-prefix", str(tmp_path), "install"],
        input="2\n\n\n\n",  # choose English, then provide empty inputs to force an early error
        text=True,
        capture_output=True,
        cwd=REPO_ROOT,
        check=False,
        env={
            **os.environ,
            # Keep provider env present so later checks don't hijack the flow.
            "CLOUDFLARE_API_TOKEN": "test-token",
        },
    )

    combined = (proc.stdout or "") + "\n" + (proc.stderr or "")
    assert "Select language" in combined or "选择语言" in combined
    assert proc.returncode != 0


def test_tp_install_uses_line_separated_followup_prompts(tmp_path: Path) -> None:
    proc = subprocess.run(
        [sys.executable, str(CLI_PATH), "--root-prefix", str(tmp_path), "install"],
        input="1\n\n\n\n",  # choose Chinese, then leave required fields empty
        text=True,
        capture_output=True,
        cwd=REPO_ROOT,
        check=False,
        env=os.environ,
    )

    combined = (proc.stdout or "") + "\n" + (proc.stderr or "")
    assert "Select language / 选择语言:" in combined
    assert "www 域名:\n> " in combined
    assert "edge 域名:\n> " in combined
    assert "DNS provider:\n> " in combined
    assert proc.returncode != 0
