# /analyze — Run Flutter Static Analysis

Run `flutter analyze` on the project and report any issues.

## Steps

1. Run `flutter analyze` in the project root
2. Parse output for errors and warnings
3. For each error:
   - Show file path, line number, and error message
   - Suggest a fix if the pattern is recognizable
4. Summarize: X errors, Y warnings, Z info messages

## Usage

```
/analyze                    # Full project analysis
/analyze lib/features/run/  # Analyze specific directory
```
