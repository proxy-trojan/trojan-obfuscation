from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT_PATH = REPO_ROOT / "scripts" / "release" / "tp-install.sh"


def test_tp_install_sh_exists_and_mentions_sha256() -> None:
    assert SCRIPT_PATH.exists()
    text = SCRIPT_PATH.read_text(encoding="utf-8")
    assert "sha256sum" in text
    assert "releases/latest/download" in text
    assert "tp install" in text
