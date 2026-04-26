import pathlib


def test_validate_full_installer_script_exists_and_mentions_core_steps() -> None:
    path = pathlib.Path("scripts/validate_full_installer_v1.sh")
    assert path.exists()
    text = path.read_text(encoding="utf-8")
    assert "manifest + provider registry" in text
    assert "render + bundle export" in text
    assert "installer apply flow" in text
    assert "tp cli" in text
