---
name: systematic-debugging
description: >-
  Use when diagnosing a bug, failing test, or unexpected runtime behavior.
  Enforces reproduction and root-cause tracing before any code edit.
---

# Systematic Debugging

Do not guess-and-patch. Follow these four steps in order:

1. **Reproduce:** Run the failing test, command, or minimal reproducer and observe the exact error output.
2. **Isolate:** Trace the data/control flow back to the exact file, symbol, and condition where reality diverges from expectation. Read only the relevant code slices.
3. **Hypothesize & Fix:** State the root cause in one sentence, apply the minimal targeted fix, and avoid unrelated refactors.
4. **Verify:** Re-run the reproducer and adjacent tests after the final edit to confirm the fix and check for regressions.
