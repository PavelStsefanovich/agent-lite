---
name: dev-python
description: >-
  Use when working on Python projects, managing Python dependencies, or running
  Python commands (including backend/ and infra/). Enforces uv for package and
  virtual environment management.
---

# Python Development (`uv`)

Always use `uv` (`uv init`, `uv add`, `uv sync`, `uv run`) as the package and virtual environment manager for all Python projects. Never use raw `pip`, `venv`, `pipenv`, or `poetry`. Use `uv` to install required Python version - ask the user for all new projects, do not guess based on installed versions of Python.
