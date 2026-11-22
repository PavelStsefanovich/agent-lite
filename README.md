# agent-lite

A zero-bloat, per-project alternative to heavy agent process frameworks (`obra/superpowers`). Designed to be **isolated to individual projects**, **compatible with any coding agent**, and **effortlessly removable**.

## What's Included

- **`AGENTS.md`** (~15 lines of always-on guardrails):
  - Scales process to blast radius (direct edit for small fixes; concise bullet plan for multi-file changes).
  - Bans full implementation code blocks inside plans (eliminates double-writing token burn).
  - Enforces root-cause debugging and mandatory post-edit test verification.
- **3 On-Demand Skills** (`.agents/skills/*/SKILL.md`, loaded only when relevant):
  - `systematic-debugging`: 4-step Reproduce → Isolate → Fix → Verify.
  - `tdd-lite`: Single-context Red-Green-Refactor.
  - `verify-before-done`: Exact observed output before claiming completion.

## Quick Install (Per-Project)

Clone this repo anywhere on a new machine, then install into any project:

```bash
./install.sh /path/to/your-project
```

### Useful Flags

- **Keep it completely local to your working copy** (adds entries to `.git/info/exclude` without touching `.gitignore`):
  ```bash
  ./install.sh --git-exclude /path/to/your-project
  ```
- **Add Claude Code compatibility links** (`CLAUDE.md -> AGENTS.md` and `.claude/skills/*`):
  ```bash
  ./install.sh --claude /path/to/your-project
  ```
- **Preview changes without writing:**
  ```bash
  ./install.sh --dry-run /path/to/your-project
  ```
- **Cleanly uninstall from a project** (preserves any other rules/skills you already had):
  ```bash
  ./install.sh --uninstall /path/to/your-project
  ```

## Supported Agents

Works out of the box with **Antigravity**, **Codex**, **Cursor**, **Windsurf**, **GitHub Copilot**, **OpenCode**, and **Claude Code** (use `--claude` if your Claude Code setup expects `CLAUDE.md` / `.claude/skills/`).
