import subprocess
from pathlib import Path

SCRIPT_PATH = Path(__file__).resolve().parents[1] / "repo" / "cleanup-branches.sh"


def _run(cmd: list[str], cwd: Path, check: bool = True) -> subprocess.CompletedProcess[str]:
    proc = subprocess.run(cmd, cwd=cwd, text=True, capture_output=True, check=False)
    if check and proc.returncode != 0:
        raise AssertionError(
            f"command failed: {' '.join(cmd)}\n"
            f"cwd={cwd}\n"
            f"exit={proc.returncode}\n"
            f"stdout:\n{proc.stdout}\n"
            f"stderr:\n{proc.stderr}"
        )
    return proc


def _git(cwd: Path, *args: str) -> str:
    return _run(["git", *args], cwd=cwd).stdout.strip()


def _configure_git_identity(repo: Path) -> None:
    _git(repo, "config", "user.name", "Test User")
    _git(repo, "config", "user.email", "test@example.com")


def _write_commit(repo: Path, relpath: str, content: str, message: str) -> None:
    path = repo / relpath
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)
    _git(repo, "add", relpath)
    _git(repo, "commit", "-m", message)


def _list_local_branches(repo: Path) -> set[str]:
    output = _git(repo, "for-each-ref", "--format=%(refname:short)", "refs/heads")
    return {line for line in output.splitlines() if line}


def _list_remote_refs(repo: Path) -> set[str]:
    output = _git(repo, "for-each-ref", "--format=%(refname:short)", "refs/remotes/origin")
    return {line for line in output.splitlines() if line}


def _list_origin_heads(origin: Path) -> set[str]:
    output = _git(origin, "for-each-ref", "--format=%(refname:short)", "refs/heads")
    return {line for line in output.splitlines() if line}


def _init_repo_fixture(tmp_path: Path) -> tuple[Path, Path]:
    origin = tmp_path / "origin.git"
    seed = tmp_path / "seed"
    work = tmp_path / "work"

    _run(["git", "init", "--bare", str(origin)], cwd=tmp_path)
    _run(["git", "init", "-b", "main", str(seed)], cwd=tmp_path)
    _configure_git_identity(seed)

    _write_commit(seed, "README.md", "seed\n", "seed main")
    _git(seed, "remote", "add", "origin", str(origin))
    _git(seed, "push", "-u", "origin", "main")
    _git(origin, "symbolic-ref", "HEAD", "refs/heads/main")

    _git(seed, "switch", "-c", "feature/remote-stale")
    _write_commit(seed, "remote-stale.txt", "remote stale\n", "add remote stale branch")
    _git(seed, "push", "-u", "origin", "feature/remote-stale")

    _git(seed, "switch", "main")
    _git(seed, "switch", "-c", "feature/current")
    _write_commit(seed, "current.txt", "current branch\n", "add current branch")
    _git(seed, "push", "-u", "origin", "feature/current")

    _git(seed, "switch", "main")
    _run(["git", "clone", str(origin), str(work)], cwd=tmp_path)
    _configure_git_identity(work)
    _git(work, "switch", "--track", "origin/feature/current")
    _git(work, "branch", "feature/local-stale")

    return origin, work


def test_help_describes_default_dry_run(tmp_path: Path) -> None:
    proc = _run(["bash", str(SCRIPT_PATH), "--help"], cwd=tmp_path, check=False)

    assert proc.returncode == 0
    assert "Usage:" in proc.stdout
    assert "dry-run" in proc.stdout.lower()
    assert "--apply" in proc.stdout


def test_default_mode_is_dry_run_and_only_prints_candidates(tmp_path: Path) -> None:
    _, work = _init_repo_fixture(tmp_path)

    proc = _run(["bash", str(SCRIPT_PATH)], cwd=work, check=False)

    assert proc.returncode == 0
    assert "dry-run" in proc.stdout.lower()
    assert "would delete local branch: feature/local-stale" in proc.stdout
    assert "would delete remote branch: origin/feature/remote-stale" in proc.stdout
    assert "would delete local branch: feature/current" not in proc.stdout
    assert "would delete local branch: main" not in proc.stdout
    assert "would delete remote branch: origin/feature/current" not in proc.stdout
    assert "would delete remote branch: origin/main" not in proc.stdout
    assert "would delete remote branch: origin/HEAD" not in proc.stdout

    assert _list_local_branches(work) == {"feature/current", "feature/local-stale", "main"}
    assert _list_remote_refs(work) == {
        "origin/HEAD",
        "origin/feature/current",
        "origin/feature/remote-stale",
        "origin/main",
    }


def test_apply_deletes_only_eligible_local_and_remote_branches(tmp_path: Path) -> None:
    origin, work = _init_repo_fixture(tmp_path)

    proc = _run(["bash", str(SCRIPT_PATH), "--apply"], cwd=work, check=False)

    assert proc.returncode == 0
    assert "deleted local branch: feature/local-stale" in proc.stdout
    assert "deleted remote branch: origin/feature/remote-stale" in proc.stdout
    assert "deleted local branch: feature/current" not in proc.stdout
    assert "deleted local branch: main" not in proc.stdout
    assert "deleted remote branch: origin/feature/current" not in proc.stdout
    assert "deleted remote branch: origin/main" not in proc.stdout
    assert "deleted remote branch: origin/HEAD" not in proc.stdout

    assert _git(work, "branch", "--show-current") == "feature/current"
    assert _list_local_branches(work) == {"feature/current", "main"}
    assert _list_remote_refs(work) == {"origin/HEAD", "origin/feature/current", "origin/main"}
    assert _list_origin_heads(origin) == {"feature/current", "main"}
