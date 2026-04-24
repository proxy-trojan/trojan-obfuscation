import pathlib


def test_validation_script_exists() -> None:
    assert pathlib.Path("scripts/validate_repo_cleanup_installer_routing.sh").exists()
