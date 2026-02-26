#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "=== [1/5] Runtime TODO 回归检查 ==="
bash "$REPO_ROOT/scripts/check_no_runtime_todo.sh"

echo "=== [2/5] C++ 共享核心测试 ==="
cmake -S "$REPO_ROOT" -B "$REPO_ROOT/build"
cmake --build "$REPO_ROOT/build"
ctest --test-dir "$REPO_ROOT/build" --output-on-failure

echo "=== [3/5] Android 单元测试 ==="
cd "$REPO_ROOT/android"
./gradlew :supercamera:testDebugUnitTest :supercamera-ui:testDebugUnitTest

echo "=== [4/5] iOS SuperCameraKit 测试 ==="
cd "$REPO_ROOT/ios/SuperCameraKit"
swift test

echo "=== [5/5] iOS SuperCameraUI 测试 ==="
cd "$REPO_ROOT/ios/SuperCameraUI"
swift test

echo ""
echo "PASS: MVP 验证基线通过"
