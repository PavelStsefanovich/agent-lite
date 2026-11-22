---
name: verify-before-done
description: >-
  Use before reporting any task as complete. Ensures all claims of passing
  tests, builds, or behavior match actual post-edit tool output.
---

# Verify Before Done

1. Run the project's test, lint, or typecheck command(s) **after** your final edit.
2. Inspect the actual exit code and output—never extrapolate from earlier runs.
3. In your final response, report only observed file paths, symbol names, and exact test/command scope and results. If a check could not run, state why explicitly.
