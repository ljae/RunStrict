# /test — Run Flutter Tests

Run Flutter tests and report results.

## Steps

1. Run `flutter test` (or specific test file if provided)
2. Report pass/fail counts
3. For failures: show test name, expected vs actual, file path
4. Suggest fixes for common failure patterns

## Usage

```
/test                                    # Run all tests
/test test/widget_test.dart              # Run specific test file
/test --coverage                         # Run with coverage report
/test --plain-name "App smoke test"      # Run specific test by name
```
