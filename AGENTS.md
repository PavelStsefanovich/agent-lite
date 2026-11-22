<!-- agent-lite:start -->
## Agent-Lite Engineering Rules

- **Scale process to blast radius:**
  - *Small, unambiguous edit (< 20 lines, 1 file):* Edit directly and verify. No plan doc, no subagents.
  - *Multi-file or architectural change:* Present a concise bullet plan (max 10 bullets) and wait for confirmation before editing.
- **No implementation code in plans:** Plans may only specify target file paths, symbol names, data flow, edge cases, and test strategy—never write full code blocks into a plan.
- **Root-cause first:** For bugs, reproduce and trace the actual root cause before modifying code. Never guess-and-patch.
- **Keep work in one context when sequential:** Only use subagents for independent parallel tasks or broad codebase search.
- **Verify before completion:** Run relevant tests, linters, or build checks after your final edit and report the exact observed results. Never claim success without running checks.
- **AWS Safety Guardrail:**
  - **AWS & IaC Safety:** Run local/read-only checks autonomously (`docker build`, `sam validate`, `cdk synth`, `cdk diff`, `terraform plan`, `webapp-testing`).
  - **Explicit Approval for Mutations:** Never run `cdk deploy`, `terraform apply`, `sam deploy`, or mutating `aws` CLI commands without explicit user confirmation.
<!-- agent-lite:end -->
