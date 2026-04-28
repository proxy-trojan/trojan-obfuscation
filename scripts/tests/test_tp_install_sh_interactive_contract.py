import os
import subprocess
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT_PATH = REPO_ROOT / "scripts" / "release" / "tp-install.sh"


def test_tp_install_script_contains_shell_side_interactive_collection() -> None:
    script = SCRIPT_PATH.read_text(encoding="utf-8")
    assert "collect_interactive_args_from_tty" in script
    assert "--non-interactive" in script
    assert 'read -r -p "> " lang_choice </dev/tty' in script
    assert 'prompt_tty_line' in script
    assert 'DNS_PROVIDER_OPTIONS=' in script
    assert 'for provider in "${DNS_PROVIDER_OPTIONS[@]}"' in script
    assert 'y / Y / yes / YES' in script


def test_tp_install_script_preserves_passthrough_non_interactive_args(tmp_path: Path) -> None:
    script = SCRIPT_PATH.read_text(encoding="utf-8")

    fake_bin = tmp_path / "bin"
    fake_bin.mkdir()
    log_path = tmp_path / "tp.log"

    (fake_bin / "curl").write_text(
        f"""#!/usr/bin/env bash
set -euo pipefail
output=""
url=""
while (($# > 0)); do
  case "$1" in
    -o)
      output="$2"
      shift 2
      ;;
    -fsSL)
      shift
      ;;
    *)
      url="$1"
      shift
      ;;
  esac
done
if [[ -z "$output" ]]; then
  echo "missing -o" >&2
  exit 1
fi
if [[ "$url" == *.sha256 ]]; then
  printf 'deadbeef  tp-linux-amd64\n' >"$output"
else
  cat >"$output" <<'TP'
#!/usr/bin/env bash
printf '%s\n' "$*" > {log_path}
TP
  chmod +x "$output"
fi
""",
        encoding="utf-8",
    )
    (fake_bin / "curl").chmod(0o755)

    (fake_bin / "sha256sum").write_text(
        """#!/usr/bin/env bash
printf 'deadbeef  %s\n' "$1"
""",
        encoding="utf-8",
    )
    (fake_bin / "sha256sum").chmod(0o755)

    (fake_bin / "uname").write_text(
        """#!/usr/bin/env bash
if [[ "${1:-}" == "-m" ]]; then
  echo x86_64
else
  /usr/bin/uname "$@"
fi
""",
        encoding="utf-8",
    )
    (fake_bin / "uname").chmod(0o755)

    (fake_bin / "install").write_text(
        """#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "-d" ]]; then
  mkdir -p "$2"
  exit 0
fi
if [[ "${1:-}" == "-m" ]]; then
  shift 2
fi
cp "$1" "$2"
chmod +x "$2"
""",
        encoding="utf-8",
    )
    (fake_bin / "install").chmod(0o755)

    (fake_bin / "mv").write_text(
        """#!/usr/bin/env bash
/usr/bin/mv "$@"
""",
        encoding="utf-8",
    )
    (fake_bin / "mv").chmod(0o755)

    proc = subprocess.run(
        [
            "bash",
            "-lc",
            script,
            "bash",
            "--",
            "--non-interactive",
            "--lang",
            "zh-CN",
            "--www-domain",
            "www.example.com",
            "--edge-domain",
            "edge.example.com",
            "--dns-provider",
            "cloudflare",
            "--yes",
        ],
        text=True,
        capture_output=True,
        cwd=REPO_ROOT,
        check=False,
        env={
            **os.environ,
            "PATH": f"{fake_bin}:{os.environ['PATH']}",
            "CLOUDFLARE_API_TOKEN": "test-token",
        },
    )

    assert proc.returncode in (0, 1)
    combined = (proc.stdout or "") + "\n" + (proc.stderr or "")
    assert "running: tp install --non-interactive --lang zh-CN --www-domain www.example.com --edge-domain edge.example.com --dns-provider cloudflare --yes" in combined
