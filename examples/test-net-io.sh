#!/bin/bash
#
# Demo script for the Zig net-logger plugin.
#
# Run this script inside `qcontrol wrap`, similar to test-file-ops.sh:
#
#   qcontrol bundle --plugins ./net-logger -o ./net-logger-demo.so
#   qcontrol wrap --bundle ./net-logger-demo.so -- ./test-net-io.sh
#
#   qcontrol wrap --bundle ./net-logger-demo.so -- ./test-net-io.sh https://example.com/
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
