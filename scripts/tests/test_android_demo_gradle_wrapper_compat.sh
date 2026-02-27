#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ROOT_WRAPPER="$REPO_ROOT/android/gradle/wrapper/gradle-wrapper.properties"
DEMO_WRAPPER="$REPO_ROOT/samples/android-app/gradle/wrapper/gradle-wrapper.properties"

expected_url="$(grep '^distributionUrl=' "$ROOT_WRAPPER")"
actual_url="$(grep '^distributionUrl=' "$DEMO_WRAPPER")"

if [[ "$actual_url" != "$expected_url" ]]; then
  echo "FAIL: Android demo wrapper version mismatch"
  echo "expected: $expected_url"
  echo "actual:   $actual_url"
  exit 1
fi

echo "PASS: Android demo wrapper is compatible with main Android project"
