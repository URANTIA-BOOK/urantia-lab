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

out="$(choose_caddy_http_port "" false)"
[[ "$out" == "8080" ]] || fail "non-TTY published port must be 8080 (got '$out')"
out="$(choose_caddy_http_port "9080" true)"
[[ "$out" == "9080" ]] || fail "stored port must be kept (got '$out')"
out="$(HTTP_PORT=9090 choose_caddy_http_port "9080" true)"
[[ "$out" == "9090" ]] || fail "HTTP_PORT must win over a stored port (got '$out')"

out="$(existing_env_choice "" "9080" true)"
[[ "$out" == "9080" ]] || fail "existing_env_choice must keep a written value (got '$out')"
out="$(existing_env_choice "9090" "9080" true)"
[[ "$out" == "9090" ]] || fail "existing_env_choice overwrite must win (got '$out')"
if existing_env_choice "" "" true; then
  fail "existing_env_choice must miss when nothing is written"
fi
if init_interviewing; then
  fail "sourced choosers must not interview unless init-env set INIT_INTERVIEW"
fi

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
os.environ.pop("CADDY_HTTP_PORT", None)
os.environ.pop("HTTP_PORT", None)
os.environ.pop("EDGE_PUBLIC_URL", None)
os.environ.pop("EDGE_HOSTNAME", None)
os.environ.pop("PROJECT_NAME", None)

script = root / "make" / "init-env.sh"
pid, fd = pty.fork()
if pid == 0:
    os.chdir(root)
    os.execv(str(script), [str(script)])

answers = b"\n9090\n/v1\n\n"
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
if "CADDY_HTTP_PORT=9090" not in text:
    sys.stderr.write(out + "\n")
    sys.exit("interactive init must persist Published port 9090")
if "EDGE_PUBLIC_URL=http://localhost:9090\n" not in text:
    sys.stderr.write(out + "\n")
    sys.exit("interactive init must derive localhost from the chosen port")
if "Published origin" in text:
    sys.stderr.write(out + "\n")
    sys.exit("chooser help leaked into EDGE_PUBLIC_URL")
if "API_PUBLIC_URL=http://localhost:9090/v1" not in text:
    sys.stderr.write(out + "\n")
    sys.exit("interactive init must derive API_PUBLIC_URL from port + /v1")
if "Published port" not in out:
    sys.stderr.write(out + "\n")
    sys.exit("interactive init must ask for Published port")
print("init-env TTY: port 9090 + /v1 + localhost stamps a single-line origin")

# make validate sources choosers on the operator TTY. /v1 on stdin must not
# become the default (that is how make up failed after hostname).
chooser_out = tmpdir / "sourced-choosers.out"
os.environ["CHOOSER_OUT"] = str(chooser_out)
pid, fd = pty.fork()
if pid == 0:
    os.chdir(root)
    os.execv(
        "/bin/bash",
        [
            "bash",
            "-c",
            """
set -euo pipefail
source make/edge-origin.sh
{
  printf '%s\\n' "$(choose_edge_public_url "" false 8080)"
  printf '%s\\n' "$(choose_caddy_api_path "" false)"
} >"$CHOOSER_OUT"
""",
        ],
    )
os.write(fd, b"/v1\n/v1\n")
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
sourced = b"".join(chunks).decode("utf-8", "replace")
written = chooser_out.read_text() if chooser_out.exists() else ""
if "Published hostname" in sourced or "Papers API path" in sourced:
    sys.stderr.write(sourced + "\n")
    sys.exit("sourced choosers on a TTY must not interview")
if written != "http://localhost:8080\n/dev-api\n":
    sys.stderr.write(sourced + "\n" + written + "\n")
    sys.exit("sourced choosers on a TTY must default, not read stdin")
print("sourced choosers on a TTY default without interviewing")

# Re-init (existing .env.shared, same path as make up → init) keeps the file.
# A TTY must not interview again.
existed = tmpdir / ".env.existed"
existed.write_text(
    "COMPOSE_PROJECT_NAME=urantialab\n"
    "CADDY_HTTP_PORT=9080\n"
    "CADDY_API_PATH=/v1\n"
    "EDGE_PUBLIC_URL=http://localhost:9080\n"
    "POSTGRES_USER=urantia\n"
    "POSTGRES_PASSWORD=testpass\n"
    "POSTGRES_DB=papers\n"
    "HUB_DB=hub\n"
    "REDIS_PASSWORD=testredis\n"
    "NEXTAUTH_SECRET=testsecret\n"
    "POSTGRES_HOST_PORT=5433\n"
    "REDIS_HOST_PORT=6380\n"
)
os.environ["SHARED_ENV_FILE"] = str(existed)
pid, fd = pty.fork()
if pid == 0:
    os.chdir(root)
    os.execv(str(script), [str(script)])
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
re_out = b"".join(chunks).decode("utf-8", "replace")
re_text = existed.read_text()
for prompt in ("Published port", "Papers API path", "Published hostname", "Compose project name"):
    if prompt in re_out:
        sys.stderr.write(re_out + "\n")
        sys.exit(f"re-init TTY must not ask {prompt} when the file already has it")
if "CADDY_HTTP_PORT=9080" not in re_text:
    sys.stderr.write(re_out + "\n")
    sys.exit("re-init must keep the stored published port")
if "EDGE_PUBLIC_URL=http://localhost:9080\n" not in re_text:
    sys.stderr.write(re_out + "\n")
    sys.exit("re-init must keep the stored localhost origin")
if "API_PUBLIC_URL=http://localhost:9080/v1" not in re_text:
    sys.stderr.write(re_out + "\n")
    sys.exit("re-init must keep the stored API path on the stored origin")
if "Lab identity" not in re_out:
    sys.stderr.write(re_out + "\n")
    sys.exit("re-init TTY must finish without reading stdin")
print("init-env re-init TTY: existing file is kept, no interview")
PY

echo "edge-origin: chooser stdout is a URL; /v1 survives init"
