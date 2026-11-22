---
name: plan-and-review
description: >-
  Use when planning multi-file or architectural changes, conducting design
  reviews or multi-item walkthroughs, or locking down a plan in Markdown for
  a fresh execution session.
---

# Planning & Design Reviews

- **Concise Bullet Plans:** Keep plans to at most 10 bullets specifying target file paths, symbol names, data flow, edge cases, and verification strategy. Never write full implementation code blocks into a plan.
- **One Item at a Time:** During planning, design reviews, and multi-item walkthroughs, present a brief agenda and lock down one item at a time—do not jump ahead until the user confirms. Once all items are locked down and confirmed, implement the full agreed plan end-to-end.
- **Pre-Change Advisory:** Check for and surface potential collisions, redundancies with existing code/config, and relevant best practices before locking down changes.
- **Locking Plans to Markdown (Fresh-Session Handoff):** For larger multi-file or greenfield work executed in a fresh session, write the locked plan to `.md` (optionally using minimal `type: plan` / `status: locked` YAML frontmatter and listing it in `docs/index.md` if present) covering:
  1. Key existing files to read first.
  2. Locked decisions, non-goals, and rejected approaches (with brief rationale).
  3. Phased checklist of file paths, symbol names, data flow, and edge cases (no full code blocks).
  4. Exact verification commands and expected outputs.
