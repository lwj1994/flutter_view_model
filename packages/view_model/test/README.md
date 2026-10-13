# Test and coverage checks

Run all ViewModel suites serially and in declaration order. Global registry,
configuration and lifecycle state are shared. Create ViewModels in spec builders,
resolve them through a test binding getter, and dispose that binding in teardown.

From `packages/view_model`, with `FLUTTER_ROOT` pointing to the selected Flutter
SDK (GitHub Actions sets it automatically):

```sh
flutter test --no-pub --concurrency=1 --coverage --coverage-path coverage/debug.info
"$FLUTTER_ROOT/bin/dart" \
  --packages="$FLUTTER_ROOT/packages/flutter_tools/.dart_tool/package_config.json" \
  ../../.github/scripts/test_release_conditions.dart \
  test --no-pub --concurrency=1 --coverage --coverage-path coverage/release.info \
  --dart-define=dart.vm.product=true test/release_contract_test.dart
python3 ../../.github/scripts/check_view_model_coverage.py \
  coverage/debug.info coverage/release.info --output coverage/lcov.info
```

The second run uses Flutter's normal test runner and coverage collector, with
the engine's `--disable-dart-asserts` flag and release constants. It checks the
actual assertion mode before testing release fallbacks. This is a JIT test of
release conditions, not an AOT build or device integration test. The adapter
uses the selected SDK's `flutter_tools` dependencies and does not modify the SDK.

The gate requires **100% line coverage** of the main package. It merges hits and
keeps the union of executable lines from both modes, including lines seen only
in debug or release. It does not exclude production source files or uncovered
lines. This percentage does not measure branch or path coverage.
