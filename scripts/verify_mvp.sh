#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "=== [1/4] C++ 共享核心测试 ==="
cmake -S "$REPO_ROOT" -B "$REPO_ROOT/build"
cmake --build "$REPO_ROOT/build"
ctest --test-dir "$REPO_ROOT/build" --output-on-failure

echo "=== [2/4] Android 单元测试 ==="
cd "$REPO_ROOT/android"
./gradlew :supercamera:testDebugUnitTest :supercamera-ui:testDebugUnitTest

echo "=== [3/4] iOS SuperCameraKit 测试 ==="
cd "$REPO_ROOT/ios/SuperCameraKit"
swift test

echo "=== [4/4] iOS SuperCameraUI 测试 ==="
cd "$REPO_ROOT/ios/SuperCameraUI"
swift test

echo ""
echo "PASS: MVP 验证基线通过"
