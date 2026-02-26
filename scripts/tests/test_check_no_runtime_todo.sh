#!/usr/bin/env bash
set -euo pipefail

TMP_FILE="$(mktemp)"
trap 'rm -f "$TMP_FILE"' EXIT

echo "// TODO: real implementation still pending" > "$TMP_FILE"

if bash "$(cd "$(dirname "$0")/.." && pwd)/check_no_runtime_todo.sh" "$TMP_FILE"; then
  echo "Expected TODO check to fail, but it passed"
  exit 1
fi

echo "PASS: TODO check correctly fails on TODO marker"
