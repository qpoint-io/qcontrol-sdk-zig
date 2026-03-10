#!/bin/bash
#
# Demo script for the Zig net-logger plugin in proxy-backed wrap mode.
#
# Run this script inside `qcontrol wrap`, similar to test-file-ops.sh:
#
#   cd net-logger && zig build -Doptimize=ReleaseFast
#   QCONTROL_PLUGINS=./net-logger/zig-out/lib/libnet_logger.so \
#     qcontrol wrap -- ./test-net-io.sh
#
#   QCONTROL_PLUGINS=./net-logger/zig-out/lib/libnet_logger.so \
#     qcontrol wrap -- ./test-net-io.sh https://example.com/
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
URL="${1:-https://example.com/}"
LOG_FILE="${QCONTROL_LOG_FILE:-/tmp/qcontrol.log}"

echo "Running client request against: $URL"
python3 "$SCRIPT_DIR/test-net-client.py" "$URL"

echo
echo "If the net-logger plugin is active, inspect:"
echo "  $LOG_FILE"
echo
echo "Suggested check:"
echo "  grep net_logger.zig \"$LOG_FILE\""
