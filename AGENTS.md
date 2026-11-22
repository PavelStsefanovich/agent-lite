<!-- agent-lite:start -->
## Agent-Lite Engineering Rules

- **Scale process to blast radius:**
  - *Small, unambiguous edit (< 20 lines, 1 file):* Edit directly and verify. No plan doc, no subagents.
  - *Multi-file change, architectural change, or design review:* Use the `plan-and-review` skill—lock down one item at a time, keep plans concise with no full code blocks, and wait for confirmation before editing.
- **Pre-Change Advisory (Collisions, Redundancies & Best Practices):** Before implementing requested changes, check for and notify the user of any potential collisions, redundancies with existing configuration/code, or relevant best practices.
- **Root-cause first:** For bugs, reproduce and trace the actual root cause before modifying code. Never guess-and-patch.
- **Keep work in one context when sequential:** Only use subagents for independent parallel tasks or broad codebase search.
- **Verify before completion:** Run relevant tests, linters, or build checks after your final edit and report only observed file paths, symbol names, and exact command/exit-code results. Never extrapolate from earlier runs; if a check could not run, state why explicitly.
- **Mutation & Deploy Safety:** Run local, read-only validation and dry-run checks autonomously. Never run deployment, infrastructure-mutating, or external/production-affecting commands without explicit user confirmation.
<!-- agent-lite:end -->
