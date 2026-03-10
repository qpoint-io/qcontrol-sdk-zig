#!/usr/bin/env bash
#
# Demo script for the Zig net-transform plugin in proxy-backed wrap mode.
#
# Run this script inside `qcontrol wrap`:
#
#   cd net-transform && zig build -Doptimize=ReleaseFast
#   QCONTROL_PLUGINS=./net-transform/zig-out/lib/libnet_transform.so \
#     qcontrol wrap -- ./test-net-transform.sh
#

set -euo pipefail

cd "$(dirname "$0")"

cleanup() {
  if [[ -n "${server_pid:-}" ]]; then
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
  fi
  if [[ -n "${tmpdir:-}" && -d "$tmpdir" ]]; then
    rm -rf "$tmpdir"
  fi
}
trap cleanup EXIT

tmpdir="$(mktemp -d)"
port_file="$tmpdir/port"

python3 - "$port_file" <<'PY' &
import http.server
import sys

port_file = sys.argv[1]

class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        body = b"hello from demo server\n"
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        pass

server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
with open(port_file, "w", encoding="utf-8") as fh:
    fh.write(str(server.server_port))
    fh.flush()
server.serve_forever()
PY
server_pid=$!

for _ in $(seq 1 50); do
  if [[ -s "$port_file" ]]; then
    break
  fi
  sleep 0.1
done

if [[ ! -s "$port_file" ]]; then
  echo "failed to start demo HTTP server" >&2
  exit 1
fi

port="$(cat "$port_file")"

curl --silent --show-error --noproxy "" "http://127.0.0.1:${port}/"
