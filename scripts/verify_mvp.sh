#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "=== [1/8] Runtime TODO 回归检查 ==="
bash "$REPO_ROOT/scripts/check_no_runtime_todo.sh"

echo "=== [2/8] C++ 共享核心测试 ==="
cmake -S "$REPO_ROOT" -B "$REPO_ROOT/build"
cmake --build "$REPO_ROOT/build"
ctest --test-dir "$REPO_ROOT/build" --output-on-failure

echo "=== [3/8] Android 单元测试 ==="
cd "$REPO_ROOT/android"
./gradlew :supercamera:testDebugUnitTest :supercamera-ui:testDebugUnitTest

echo "=== [4/8] iOS SuperCameraKit 测试 ==="
cd "$REPO_ROOT/ios/SuperCameraKit"
swift test

echo "=== [5/8] iOS SuperCameraUI 测试 ==="
cd "$REPO_ROOT/ios/SuperCameraUI"
swift test

echo "=== [6/8] Android Demo 构建 ==="
cd "$REPO_ROOT/android"
./gradlew -p ../samples/android-app :app:assembleDebug
echo "✓ Android demo APK built"

echo "=== [7/8] iOS Demo Tests ==="
cd "$REPO_ROOT/samples/ios-app/SuperCameraDemo"
swift test
echo "✓ iOS demo tests passed"

echo "=== [8/8] Sample README Checks ==="
bash "$REPO_ROOT/scripts/tests/test_sample_readme_has_manual_checklist.sh"

echo ""
echo "PASS: MVP 验证基线通过"
