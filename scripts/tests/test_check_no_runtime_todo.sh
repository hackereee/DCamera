#!/usr/bin/env bash
set -euo pipefail

TMP_FILE_1="$(mktemp)"
TMP_FILE_2="$(mktemp)"
TMP_FILE_3="$(mktemp)"
trap 'rm -f "$TMP_FILE_1" "$TMP_FILE_2" "$TMP_FILE_3"' EXIT

SCRIPT_PATH="$(cd "$(dirname "$0")/.." && pwd)/check_no_runtime_todo.sh"

echo "// TODO: real implementation still pending" > "$TMP_FILE_1"
echo "// todo implement runtime fallback" > "$TMP_FILE_2"
echo "// implementation completed, no markers left" > "$TMP_FILE_3"

expect_fail_on_todo() {
  local file="$1"
  if bash "$SCRIPT_PATH" "$file"; then
    echo "Expected TODO check to fail for $file, but it passed"
    exit 1
  fi
}

expect_fail_on_todo "$TMP_FILE_1"
expect_fail_on_todo "$TMP_FILE_2"

bash "$SCRIPT_PATH" "$TMP_FILE_3"

echo "PASS: TODO check correctly fails on TODO marker"
