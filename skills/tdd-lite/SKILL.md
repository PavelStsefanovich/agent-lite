---
name: tdd-lite
description: >-
  Use when implementing new behavior or fixing a bug where a regression test
  can be written first. Single-context Red-Green-Refactor workflow.
---

# TDD-Lite

Keep tests fast, focused, and in a single context:

1. **Red:** Write the smallest failing test that captures the expected behavior or bug. Run it and confirm it fails for the right reason.
2. **Green:** Write the minimal production code needed to make the test pass.
3. **Refactor:** Clean up duplication or naming while keeping the test green.
4. **Confirm:** Run the relevant test suite after your final edit and report exact pass/fail counts.
