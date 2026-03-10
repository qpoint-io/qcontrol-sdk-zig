#!/usr/bin/env python3
"""
Small HTTPS/HTTP client for qcontrol network-hook demos.

Usage:
  python3 test-net-client.py [url]

Examples:
  python3 test-net-client.py
  python3 test-net-client.py https://example.com/
"""

from __future__ import annotations

import sys
import urllib.request


def main() -> int:
    url = sys.argv[1] if len(sys.argv) > 1 else "https://example.com/"
    with urllib.request.urlopen(url, timeout=10) as response:
        body = response.read(160)
        print(f"status={response.status}")
        print(body.decode("utf-8", errors="replace"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
