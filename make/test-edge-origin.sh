#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=edge-origin.sh
source "$SCRIPT_DIR/edge-origin.sh"
# shellcheck source=env-utils.sh
source "$SCRIPT_DIR/env-utils.sh"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

if grep -E '^\s*echo "' "$SCRIPT_DIR/edge-origin.sh" | grep -v '>&2'; then
  fail "chooser help must go to stderr so \$(choose_edge_public_url) stays a URL"
fi

out="$(choose_edge_public_url "" false 8080)"
[[ "$out" == "http://localhost:8080" ]] || fail "non-TTY origin must be a single URL (got '$out')"

out="$(choose_caddy_api_path "" false)"
[[ "$out" == "/dev-api" ]] || fail "non-TTY API path must be /dev-api (got '$out')"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
set_env_value "$tmp" CADDY_API_PATH "/v1"
set_env_value "$tmp" API_PUBLIC_URL "http://localhost:8080/v1"
[[ "$(read_env_value "$tmp" CADDY_API_PATH)" == "/v1" ]] || fail "set_env_value must keep /v1"
[[ "$(read_env_value "$tmp" API_PUBLIC_URL)" == "http://localhost:8080/v1" ]] \
  || fail "set_env_value must keep slashes in URLs"

if set_env_value "$tmp" EDGE_PUBLIC_URL $'Published origin\nhttp://localhost:8080' 2>/dev/null; then
  fail "set_env_value must reject a newline so sed-style writers cannot run"
fi

python3 - "$ROOT" <<'PY'
import os
import pty
import sys
import tempfile
from pathlib import Path

root = Path(sys.argv[1])
tmpdir = Path(tempfile.mkdtemp())
env_file = tmpdir / ".env.shared"
os.environ["SHARED_ENV_FILE"] = str(env_file)
os.environ.pop("CADDY_API_PATH", None)
os.environ.pop("EDGE_PUBLIC_URL", None)
os.environ.pop("EDGE_HOSTNAME", None)
os.environ.pop("PROJECT_NAME", None)

script = root / "make" / "init-env.sh"
pid, fd = pty.fork()
if pid == 0:
    os.chdir(root)
    os.execv(str(script), [str(script)])

answers = b"\n/v1\n\n"
os.write(fd, answers)
chunks = []
while True:
    try:
        data = os.read(fd, 4096)
    except OSError:
        break
    if not data:
        break
    chunks.append(data)
os.waitpid(pid, 0)
out = b"".join(chunks).decode("utf-8", "replace")
text = env_file.read_text()
if "CADDY_API_PATH=/v1" not in text:
    sys.stderr.write(out + "\n")
    sys.exit("interactive init must persist CADDY_API_PATH=/v1")
if "EDGE_PUBLIC_URL=http://localhost:8080\n" not in text:
    sys.stderr.write(out + "\n")
    sys.exit("interactive init must persist a single-line localhost origin")
if "Published origin" in text:
    sys.stderr.write(out + "\n")
    sys.exit("chooser help leaked into EDGE_PUBLIC_URL")
if "API_PUBLIC_URL=http://localhost:8080/v1" not in text:
    sys.stderr.write(out + "\n")
    sys.exit("interactive init must derive API_PUBLIC_URL from /v1")
print("init-env TTY: /v1 + localhost stamps a single-line origin")
PY

echo "edge-origin: chooser stdout is a URL; /v1 survives init"
