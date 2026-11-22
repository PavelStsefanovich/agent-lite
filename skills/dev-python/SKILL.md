---
name: dev-python
description: >-
  Use when working on Python projects, selecting Python versions, managing
  dependencies, or running Python commands. Enforces uv for Python, package,
  and virtual environment management.
---

# Python Development (`uv`)

- Always use `uv` (`uv init`, `uv add`, `uv sync`, `uv run`) for Python packages and virtual environments. Never use raw `pip`, `venv`, `pipenv`, or `poetry`.
- When initializing a new project (or when `.python-version` / `requires-python` is not already defined), ask the user for the target Python version instead of guessing from locally installed versions, then install and pin it with `uv` (`uv python install` / `uv python pin`).
- Run scripts, linters, typecheckers, and tests through `uv run` so commands execute inside the project's managed environment.
