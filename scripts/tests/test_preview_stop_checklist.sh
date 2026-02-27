#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

echo "=== Checking manual checklist for preview restart item ==="
grep -q "预览停止后可恢复" "$REPO_ROOT/docs/testing/mvp-manual-checklist.md"
echo "OK: MVP manual checklist includes preview stop/restart validation item"
