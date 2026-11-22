#!/usr/bin/env bash
set -euo pipefail

# agent-lite project installer
# Installs lightweight AGENTS.md rules + on-demand .agents/skills/ into a single project.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS=("systematic-debugging" "tdd-lite" "verify-before-done")
START_MARKER="<!-- agent-lite:start -->"
END_MARKER="<!-- agent-lite:end -->"

TARGET_DIR=""
ACTION="install"
DRY_RUN=false
USE_SYMLINK=false
CLAUDE_COMPAT=false
GIT_EXCLUDE=false

usage() {
  cat <<'EOF'
Usage: ./install.sh [OPTIONS] <project-dir>

Install or remove agent-lite in an individual project directory.

Options:
  --uninstall      Remove agent-lite rules block and installed skills from <project-dir>
  --claude         Also link CLAUDE.md -> AGENTS.md (if absent) and .claude/skills/<skill>
  --symlink        Symlink skill folders instead of copying them
  --git-exclude    Add installed agent-lite paths to <project-dir>/.git/info/exclude
  --dry-run        Show what would be changed without modifying files
  -h, --help       Show this help message

Examples:
  ./install.sh /path/to/my-project
  ./install.sh --claude --git-exclude /path/to/my-project
  ./install.sh --uninstall /path/to/my-project
EOF
}

log() {
  printf '%s\n' "$*"
}

run_cmd() {
  if $DRY_RUN; then
    printf '[dry-run] %s\n' "$*"
  else
    "$@"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --uninstall)
      ACTION="uninstall"
      shift
      ;;
    --claude)
      CLAUDE_COMPAT=true
      shift
      ;;
    --symlink)
      USE_SYMLINK=true
      shift
      ;;
    --git-exclude)
      GIT_EXCLUDE=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      printf 'Error: unknown option: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
    *)
      if [[ -n "$TARGET_DIR" ]]; then
        printf 'Error: unexpected extra argument: %s\n' "$1" >&2
        usage >&2
        exit 1
      fi
      TARGET_DIR="$1"
      shift
      ;;
  esac
done

if [[ -z "$TARGET_DIR" ]]; then
  printf 'Error: <project-dir> is required.\n' >&2
  usage >&2
  exit 1
fi

if [[ ! -d "$TARGET_DIR" ]]; then
  printf 'Error: directory does not exist: %s\n' "$TARGET_DIR" >&2
  exit 1
fi

TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"
TARGET_AGENTS="$TARGET_DIR/AGENTS.md"
TARGET_SKILLS_DIR="$TARGET_DIR/.agents/skills"

strip_block_from_file() {
  local file="$1"
  local tmp_file
  tmp_file="$(mktemp)"
  awk -v start="$START_MARKER" -v end="$END_MARKER" '
    $0 == start { skipping=1; next }
    $0 == end { skipping=0; next }
    !skipping { print }
  ' "$file" > "$tmp_file"

  # Trim trailing blank lines; if file is now empty, remove it
  if [[ -z "$(tr -d '[:space:]' < "$tmp_file")" ]]; then
    rm -f "$tmp_file" "$file"
    log "Removed empty $file"
  else
    mv "$tmp_file" "$file"
    log "Removed agent-lite block from $file"
  fi
}

upsert_agents_md() {
  local src="$SCRIPT_DIR/AGENTS.md"
  if [[ ! -f "$TARGET_AGENTS" ]]; then
    if $DRY_RUN; then
      log "[dry-run] Create $TARGET_AGENTS"
    else
      cp "$src" "$TARGET_AGENTS"
      log "Created $TARGET_AGENTS"
    fi
    return
  fi

  if grep -Fq "$START_MARKER" "$TARGET_AGENTS"; then
    if $DRY_RUN; then
      log "[dry-run] Update existing agent-lite block in $TARGET_AGENTS"
    else
      local tmp_file
      tmp_file="$(mktemp)"
      awk -v start="$START_MARKER" -v end="$END_MARKER" '
        $0 == start { skipping=1; next }
        $0 == end { skipping=0; next }
        !skipping { print }
      ' "$TARGET_AGENTS" > "$tmp_file"
      printf '\n' >> "$tmp_file"
      cat "$src" >> "$tmp_file"
      mv "$tmp_file" "$TARGET_AGENTS"
      log "Updated agent-lite block in $TARGET_AGENTS"
    fi
  else
    if $DRY_RUN; then
      log "[dry-run] Append agent-lite block to $TARGET_AGENTS"
    else
      printf '\n' >> "$TARGET_AGENTS"
      cat "$src" >> "$TARGET_AGENTS"
      log "Appended agent-lite block to $TARGET_AGENTS"
    fi
  fi
}

install_skill() {
  local skill="$1"
  local src="$SCRIPT_DIR/skills/$skill"
  local dst="$TARGET_SKILLS_DIR/$skill"

  run_cmd mkdir -p "$TARGET_SKILLS_DIR"
  if [[ -e "$dst" || -L "$dst" ]]; then
    run_cmd rm -rf "$dst"
  fi

  if $USE_SYMLINK; then
    run_cmd ln -s "$src" "$dst"
    log "Linked skill: $dst -> $src"
  else
    run_cmd cp -R "$src" "$dst"
    log "Installed skill: $dst"
  fi

  if $CLAUDE_COMPAT; then
    local claude_skills_dir="$TARGET_DIR/.claude/skills"
    local claude_dst="$claude_skills_dir/$skill"
    run_cmd mkdir -p "$claude_skills_dir"
    if [[ -e "$claude_dst" || -L "$claude_dst" ]]; then
      run_cmd rm -rf "$claude_dst"
    fi
    run_cmd ln -s "../../.agents/skills/$skill" "$claude_dst"
    log "Linked Claude skill: $claude_dst"
  fi
}

add_git_exclude() {
  local exclude_file="$TARGET_DIR/.git/info/exclude"
  if [[ ! -d "$TARGET_DIR/.git" ]]; then
    log "Note: $TARGET_DIR is not a git repository; skipping --git-exclude"
    return
  fi

  if $DRY_RUN; then
    log "[dry-run] Add agent-lite entries to $exclude_file"
    return
  fi

  mkdir -p "$TARGET_DIR/.git/info"
  touch "$exclude_file"
  if ! grep -Fq "$START_MARKER" "$exclude_file"; then
    {
      printf '\n%s\n' "$START_MARKER"
      printf 'AGENTS.md\n'
      printf '.agents/skills/\n'
      if $CLAUDE_COMPAT; then
        printf 'CLAUDE.md\n'
        printf '.claude/skills/\n'
      fi
      printf '%s\n' "$END_MARKER"
    } >> "$exclude_file"
    log "Updated $exclude_file"
  fi
}

do_install() {
  upsert_agents_md
  for skill in "${SKILLS[@]}"; do
    install_skill "$skill"
  done

  if $CLAUDE_COMPAT; then
    local claude_md="$TARGET_DIR/CLAUDE.md"
    if [[ ! -e "$claude_md" && ! -L "$claude_md" ]]; then
      run_cmd ln -s "AGENTS.md" "$claude_md"
      log "Linked $claude_md -> AGENTS.md"
    else
      log "Note: $claude_md already exists; left untouched"
    fi
  fi

  if $GIT_EXCLUDE; then
    add_git_exclude
  fi

  log "Done. agent-lite is installed in $TARGET_DIR"
}

do_uninstall() {
  if [[ -f "$TARGET_AGENTS" ]] && grep -Fq "$START_MARKER" "$TARGET_AGENTS"; then
    if $DRY_RUN; then
      log "[dry-run] Remove agent-lite block from $TARGET_AGENTS"
    else
      strip_block_from_file "$TARGET_AGENTS"
    fi
  fi

  for skill in "${SKILLS[@]}"; do
    local dst="$TARGET_SKILLS_DIR/$skill"
    if [[ -e "$dst" || -L "$dst" ]]; then
      run_cmd rm -rf "$dst"
      log "Removed skill: $dst"
    fi
    local claude_dst="$TARGET_DIR/.claude/skills/$skill"
    if [[ -L "$claude_dst" ]]; then
      run_cmd rm -f "$claude_dst"
      log "Removed Claude skill link: $claude_dst"
    fi
  done

  # Clean up empty skill directories if we created them
  if ! $DRY_RUN; then
    rmdir "$TARGET_SKILLS_DIR" 2>/dev/null || true
    rmdir "$TARGET_DIR/.agents" 2>/dev/null || true
    rmdir "$TARGET_DIR/.claude/skills" 2>/dev/null || true
    rmdir "$TARGET_DIR/.claude" 2>/dev/null || true
  fi

  local claude_md="$TARGET_DIR/CLAUDE.md"
  if [[ -L "$claude_md" ]] && [[ "$(readlink "$claude_md")" == "AGENTS.md" ]]; then
    run_cmd rm -f "$claude_md"
    log "Removed symlink $claude_md"
  fi

  local exclude_file="$TARGET_DIR/.git/info/exclude"
  if [[ -f "$exclude_file" ]] && grep -Fq "$START_MARKER" "$exclude_file"; then
    if $DRY_RUN; then
      log "[dry-run] Remove agent-lite block from $exclude_file"
    else
      strip_block_from_file "$exclude_file"
    fi
  fi

  log "Done. agent-lite removed from $TARGET_DIR"
}

if [[ "$ACTION" == "install" ]]; then
  do_install
else
  do_uninstall
fi
