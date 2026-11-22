# agent-lite

A zero-bloat, per-project alternative to heavy agent process frameworks (`obra/superpowers`). Designed to be **isolated to individual projects**, **compatible with any coding agent**, and **effortlessly removable**.

## What's Included

- **`AGENTS.md`** (~12 lines of always-on guardrails):
  - Scales process to blast radius (direct edit for small fixes; `plan-and-review` workflow for multi-file or architectural changes).
  - Runs pre-change collision/redundancy checks, root-cause-first debugging, and single-context sequential execution.
  - Enforces post-edit verification with exact observed output and explicit approval before mutating/deploy commands.
- **Core On-Demand Skills** (`.agents/skills/*/SKILL.md`, installed by default):
  - `plan-and-review`: Concise bullet plans (no code dumps), one-item-at-a-time review lock-down, and fresh-session `.md` handoffs.
  - `systematic-debugging`: 4-step Reproduce → Isolate → Fix → Verify.
  - `tdd-lite`: Single-context Red-Green-Refactor.
- **Optional Stack Skills** (opt in via `--with <skill>` or `--all-skills`):
  - `aws-iac`: Autonomous read-only AWS/IaC checks vs. explicit-approval deploy/mutation guardrails.
  - `dev-python`: Enforces `uv` for Python version, dependency, and virtual environment management.

## Quick Install (Per-Project)

Clone this repo anywhere on a new machine, then install into any project:

```bash
./install.sh /path/to/your-project
```

### Useful Flags

- **Include optional stack skills** (`--with` is repeatable and accepts comma-separated names, or use `--all-skills`):
  ```bash
  ./install.sh --with dev-python,aws-iac /path/to/your-project
  ./install.sh --all-skills /path/to/your-project
  ```
- **Symlink skill folders instead of copying them** (keeps installed skills synced with this repo):
  ```bash
  ./install.sh --symlink /path/to/your-project
  ```
- **Keep it completely local to your working copy** (adds installed entries to git `info/exclude` without touching `.gitignore`):
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
