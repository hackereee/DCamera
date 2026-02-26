#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -gt 0 ]; then
  TARGETS=("$@")
else
  REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
  TARGETS=(
    "$REPO_ROOT/android/supercamera/src/main"
    "$REPO_ROOT/ios/SuperCameraKit/Sources"
  )
fi

if rg -n -i --pcre2 "\\bTODO\\b" "${TARGETS[@]}"; then
  echo "FAIL: unresolved runtime TODO marker found"
  exit 1
fi

echo "PASS: no unresolved runtime TODO markers"
