#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

echo "=== Checking Android demo README for manual checklist ==="
grep -q "手工验证" "$REPO_ROOT/samples/android-app/README.md"
echo "OK: Android README has 手工验证 section"

echo "=== Checking iOS demo README for manual checklist ==="
grep -q "手工验证" "$REPO_ROOT/samples/ios-app/README.md"
echo "OK: iOS README has 手工验证 section"

echo ""
echo "All sample README checks passed."
