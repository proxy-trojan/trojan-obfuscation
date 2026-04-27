import hashlib
import os
import subprocess
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT_PATH = REPO_ROOT / "tools" / "github-release-binary-installer" / "install-binary.sh"


def _run(cmd: list[str], env: dict[str, str], check: bool = True) -> subprocess.CompletedProcess[str]:
    proc = subprocess.run(cmd, cwd=REPO_ROOT, text=True, capture_output=True, env=env, check=False)
    if check and proc.returncode != 0:
        raise AssertionError(
            f"command failed: {' '.join(cmd)}\n"
            f"exit={proc.returncode}\n"
            f"stdout:\n{proc.stdout}\n"
            f"stderr:\n{proc.stderr}\n"
        )
    return proc


def _write_executable(path: Path, content: str) -> None:
    path.write_text(content, encoding="utf-8")
    path.chmod(0o755)


def test_check_only_prints_plan_and_exits_zero(tmp_path: Path) -> None:
    env = os.environ.copy()
    proc = _run(
        [
            "bash",
            str(SCRIPT_PATH),
            "--repo",
            "owner/repo",
            "--tool",
            "mytool",
            "--target",
            "linux-amd64",
            "--check-only",
        ],
        env=env,
        check=True,
    )

    assert proc.returncode == 0
    assert "mode=check-only" in proc.stdout
    assert "asset=mytool-linux-amd64" in proc.stdout
    assert "sha_url=https://github.com/owner/repo/releases/latest/download/mytool-linux-amd64.sha256" in proc.stdout


def test_install_latest_uses_sidecar_sha256_and_installs_atomically(tmp_path: Path) -> None:
    fake_bin = tmp_path / "bin"
    fake_bin.mkdir()

    # Provide a fake uname so we can force x86_64 -> linux-amd64
    _write_executable(fake_bin / "uname", "#!/bin/sh\necho x86_64\n")

    # Prepare a fake binary + sha256 sidecar (sha256sum format)
    payload = tmp_path / "mytool-linux-amd64"
    payload.write_bytes(b"hello")
    sha256 = hashlib.sha256(payload.read_bytes()).hexdigest()
    sidecar = tmp_path / "mytool-linux-amd64.sha256"
    sidecar.write_text(f"{sha256}  mytool-linux-amd64\n", encoding="utf-8")

    # Fake curl: copy local files into curl -o <out>
    curl_sh = """#!/bin/sh
set -eu
out=""
url=""
# accept both: curl <url> -o <out>  and  curl -o <out> <url>
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o)
      out="$2"
      shift 2
      ;;
    http*://*)
      url="$1"
      shift
      ;;
    -*)
      shift
      ;;
    *)
      # ignore
      shift
      ;;
  esac
done

base="$(basename "$url")"
case "$base" in
  mytool-linux-amd64) src="$FIX_BIN" ;;
  mytool-linux-amd64.sha256) src="$FIX_SHA" ;;
  *)
    echo "unknown url: $url" >&2
    exit 2
    ;;
esac

cp "$src" "$out"
"""

    curl_path = fake_bin / "curl"
    curl_path.write_text(
        curl_sh.replace("$FIX_BIN", str(payload)).replace("$FIX_SHA", str(sidecar)), encoding="utf-8"
    )
    curl_path.chmod(0o755)

    install_dir = tmp_path / "install"
    dest = install_dir / "mytool"

    env = os.environ.copy()
    env["PATH"] = f"{fake_bin}:{env['PATH']}"

    proc = _run(
        [
            "bash",
            str(SCRIPT_PATH),
            "--repo",
            "owner/repo",
            "--tool",
            "mytool",
            "--install-dir",
            str(install_dir),
        ],
        env=env,
        check=True,
    )

    assert proc.returncode == 0
    assert "installed=1" in proc.stdout
    assert dest.exists()
    assert os.access(dest, os.X_OK)
    assert dest.read_bytes() == b"hello"


def test_sha256_mismatch_fails_closed(tmp_path: Path) -> None:
    fake_bin = tmp_path / "bin"
    fake_bin.mkdir()

    _write_executable(fake_bin / "uname", "#!/bin/sh\necho x86_64\n")

    payload = tmp_path / "mytool-linux-amd64"
    payload.write_bytes(b"hello")
    sidecar = tmp_path / "mytool-linux-amd64.sha256"
    sidecar.write_text("deadbeef  mytool-linux-amd64\n", encoding="utf-8")

    curl_sh = """#!/bin/sh
set -eu
out=""
url=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o)
      out="$2"
      shift 2
      ;;
    http*://*)
      url="$1"
      shift
      ;;
    -*)
      shift
      ;;
    *)
      shift
      ;;
  esac
done

base="$(basename "$url")"
case "$base" in
  mytool-linux-amd64) src="$FIX_BIN" ;;
  mytool-linux-amd64.sha256) src="$FIX_SHA" ;;
  *)
    echo "unknown url: $url" >&2
    exit 2
    ;;
esac
cp "$src" "$out"
"""

    curl_path = fake_bin / "curl"
    curl_path.write_text(
        curl_sh.replace("$FIX_BIN", str(payload)).replace("$FIX_SHA", str(sidecar)), encoding="utf-8"
    )
    curl_path.chmod(0o755)

    install_dir = tmp_path / "install"
    dest = install_dir / "mytool"

    env = os.environ.copy()
    env["PATH"] = f"{fake_bin}:{env['PATH']}"

    proc = _run(
        [
            "bash",
            str(SCRIPT_PATH),
            "--repo",
            "owner/repo",
            "--tool",
            "mytool",
            "--install-dir",
            str(install_dir),
        ],
        env=env,
        check=False,
    )

    assert proc.returncode != 0
    assert "sha256 mismatch" in proc.stderr
    assert not dest.exists()


def test_install_target_key_env_overrides_auto_detection(tmp_path: Path) -> None:
    fake_bin = tmp_path / "bin"
    fake_bin.mkdir()

    # uname reports x86_64 but we override to linux-arm64
    _write_executable(fake_bin / "uname", "#!/bin/sh\necho x86_64\n")

    payload = tmp_path / "mytool-linux-arm64"
    payload.write_bytes(b"hello-arm64")
    sha256 = hashlib.sha256(payload.read_bytes()).hexdigest()
    sidecar = tmp_path / "mytool-linux-arm64.sha256"
    sidecar.write_text(f"{sha256}  mytool-linux-arm64\n", encoding="utf-8")

    curl_sh = """#!/bin/sh
set -eu
out=""
url=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o)
      out="$2"
      shift 2
      ;;
    http*://*)
      url="$1"
      shift
      ;;
    -*)
      shift
      ;;
    *)
      shift
      ;;
  esac
done

base="$(basename "$url")"
case "$base" in
  mytool-linux-arm64) src="$FIX_BIN" ;;
  mytool-linux-arm64.sha256) src="$FIX_SHA" ;;
  *)
    echo "unknown url: $url" >&2
    exit 2
    ;;
esac
cp "$src" "$out"
"""

    curl_path = fake_bin / "curl"
    curl_path.write_text(
        curl_sh.replace("$FIX_BIN", str(payload)).replace("$FIX_SHA", str(sidecar)), encoding="utf-8"
    )
    curl_path.chmod(0o755)

    install_dir = tmp_path / "install"
    dest = install_dir / "mytool"

    env = os.environ.copy()
    env["PATH"] = f"{fake_bin}:{env['PATH']}"
    env["INSTALL_TARGET_KEY"] = "linux-arm64"

    proc = _run(
        [
            "bash",
            str(SCRIPT_PATH),
            "--repo",
            "owner/repo",
            "--tool",
            "mytool",
            "--install-dir",
            str(install_dir),
        ],
        env=env,
        check=True,
    )

    assert proc.returncode == 0
    assert dest.exists()
    assert dest.read_bytes() == b"hello-arm64"
