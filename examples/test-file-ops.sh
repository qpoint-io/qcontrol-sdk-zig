#!/bin/bash
#
# test-file-ops.sh - Test script for qcontrol file operation plugins
#
# This script performs various file operations to verify that the
# file-logger and access-control plugins are working correctly.
#
# Usage:
#   # Direct execution (no plugins)
#   ./test-file-ops.sh
#
#   # With plugins via qcontrol wrap
#   qcontrol wrap --bundle ../path/to/bundle.so -- ./test-file-ops.sh
#
#   # Or with dynamic plugins
#   QCONTROL_PLUGINS=./file-logger.so,./access-control.so \
#     qcontrol wrap -- ./test-file-ops.sh
#
# Expected behavior with plugins:
#   - file-logger: Logs all open/read/write/close operations
#   - access-control: Blocks access to /tmp/secret* files
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test directory
TEST_DIR="/tmp/qcontrol-test-$$"

echo -e "${BLUE}=== qcontrol File Operations Test ===${NC}"
echo "Test directory: $TEST_DIR"
echo ""

# Cleanup on exit
cleanup() {
    echo -e "\n${BLUE}=== Cleanup ===${NC}"
    rm -rf "$TEST_DIR"
    rm -f /tmp/secret-test-$$ 2>/dev/null || true
    echo "Removed test files"
}
trap cleanup EXIT

# Create test directory
mkdir -p "$TEST_DIR"

#
# Test 1: Basic file creation and write
#
echo -e "${YELLOW}Test 1: Create and write to a file${NC}"
echo "Hello, qcontrol!" > "$TEST_DIR/hello.txt"
echo "  Created: $TEST_DIR/hello.txt"

#
# Test 2: Read file contents
#
echo -e "\n${YELLOW}Test 2: Read file contents${NC}"
CONTENT=$(cat "$TEST_DIR/hello.txt")
echo "  Read: '$CONTENT'"

#
# Test 3: Append to file
#
echo -e "\n${YELLOW}Test 3: Append to file${NC}"
echo "This is an appended line." >> "$TEST_DIR/hello.txt"
echo "  Appended to: $TEST_DIR/hello.txt"

#
# Test 4: Read multiple lines
#
echo -e "\n${YELLOW}Test 4: Read multiple lines${NC}"
while IFS= read -r line; do
    echo "  Line: '$line'"
done < "$TEST_DIR/hello.txt"

#
# Test 5: Write binary-ish data
#
echo -e "\n${YELLOW}Test 5: Write larger data block${NC}"
dd if=/dev/zero of="$TEST_DIR/zeros.bin" bs=1024 count=4 2>/dev/null
echo "  Created: $TEST_DIR/zeros.bin (4KB)"

#
# Test 6: Copy file (read + write)
#
echo -e "\n${YELLOW}Test 6: Copy file (exercises read + write)${NC}"
cp "$TEST_DIR/hello.txt" "$TEST_DIR/hello-copy.txt"
echo "  Copied to: $TEST_DIR/hello-copy.txt"

#
# Test 7: Create multiple files
#
echo -e "\n${YELLOW}Test 7: Create multiple files${NC}"
for i in 1 2 3; do
    echo "File number $i" > "$TEST_DIR/file-$i.txt"
    echo "  Created: $TEST_DIR/file-$i.txt"
done

#
# Test 8: Read all files
#
echo -e "\n${YELLOW}Test 8: Read all test files${NC}"
for f in "$TEST_DIR"/*.txt; do
    echo "  $f: $(head -1 "$f")"
done

#
# Test 9: Access control - attempt to access blocked path
#
echo -e "\n${YELLOW}Test 9: Access control test (should be blocked by access-control plugin)${NC}"
echo "  Attempting to create /tmp/secret-test-$$..."
if echo "secret data" > /tmp/secret-test-$$ 2>/dev/null; then
    echo -e "  ${GREEN}Created file (no access-control plugin active)${NC}"
    rm -f /tmp/secret-test-$$
else
    echo -e "  ${RED}BLOCKED - access-control plugin is working!${NC}"
fi

#
# Test 10: Access control - read blocked path
#
echo -e "\n${YELLOW}Test 10: Attempt to read from blocked path${NC}"
# First create it without the plugin blocking (if no plugin)
echo "secret" > /tmp/secret-test-$$ 2>/dev/null || true
echo "  Attempting to read /tmp/secret-test-$$..."
if cat /tmp/secret-test-$$ >/dev/null 2>&1; then
    echo -e "  ${GREEN}Read succeeded (no access-control plugin active)${NC}"
else
    echo -e "  ${RED}BLOCKED - access-control plugin is working!${NC}"
fi

#
# Test 11: Content filter test (.txt with sensitive data)
#
echo -e "\n${YELLOW}Test 11: Content filter test (.txt with sensitive data)${NC}"
echo "username=admin password=secret123 api_key=xyz789" > "$TEST_DIR/credentials.txt"
echo "  Created: $TEST_DIR/credentials.txt with sensitive content"
FILTERED=$(cat "$TEST_DIR/credentials.txt")
echo "  Read back: '$FILTERED'"
echo "  (With content-filter: passwords/secrets/api_keys should be redacted)"

#
# Test 12: Log file filter test (.log with sensitive data)
#
echo -e "\n${YELLOW}Test 12: Content filter test (.log with sensitive data)${NC}"
echo "INFO: Starting app" > "$TEST_DIR/app.log"
echo "DEBUG: secret=mysecret token=abc123" >> "$TEST_DIR/app.log"
echo "  Created: $TEST_DIR/app.log with sensitive content"
cat "$TEST_DIR/app.log" | while IFS= read -r line; do
    echo "  Line: '$line'"
done
echo "  (With content-filter: secret and token should be redacted)"

#
# Test 13: Text transform - uppercase (.upper extension)
#
echo -e "\n${YELLOW}Test 13: Text transform test (.upper - uppercase)${NC}"
echo "hello world" > "$TEST_DIR/greeting.upper"
echo "  Created: $TEST_DIR/greeting.upper"
UPPER=$(cat "$TEST_DIR/greeting.upper")
echo "  Read back: '$UPPER'"
echo "  (With text-transform: should be 'HELLO WORLD')"

#
# Test 14: Text transform - ROT13 (.rot13 extension)
#
echo -e "\n${YELLOW}Test 14: Text transform test (.rot13 - ROT13 encoding)${NC}"
echo "hello" > "$TEST_DIR/secret.rot13"
echo "  Created: $TEST_DIR/secret.rot13"
ROT13=$(cat "$TEST_DIR/secret.rot13")
echo "  Read back: '$ROT13'"
echo "  (With text-transform: 'hello' should become 'uryyb')"

#
# Test 15: Text transform - bracket wrapping (.bracket extension)
#
echo -e "\n${YELLOW}Test 15: Text transform test (.bracket - wrap in brackets)${NC}"
echo "important" > "$TEST_DIR/note.bracket"
echo "  Created: $TEST_DIR/note.bracket"
BRACKET=$(cat "$TEST_DIR/note.bracket")
echo "  Read back: '$BRACKET'"
echo "  (With text-transform: should be '[[[ important ]]]')"

#
# Summary
#
echo -e "\n${BLUE}=== Test Complete ===${NC}"
echo ""
echo "If running with qcontrol plugins, check the log output for:"
echo "  - [file_logger] entries for each file operation"
echo "  - [access_control] BLOCKED entries for /tmp/secret* access"
echo "  - [byte_counter] statistics for each file at close time"
echo "  - [content_filter] redacted patterns in .txt/.log files"
echo "  - [text_transform] custom transforms on .upper/.rot13/.bracket files"
echo ""
echo "Log file location: \$QCONTROL_LOG_FILE (default: /tmp/qcontrol.log)"
