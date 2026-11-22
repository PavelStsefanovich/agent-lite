#!/usr/bin/env bash
set -euo pipefail

# agent-lite project installer
# Installs lightweight AGENTS.md rules + on-demand .agents/skills/ into a single project.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_SKILLS=("plan-and-review" "systematic-debugging" "tdd-lite")
LEGACY_SKILLS=("verify-before-done")

START_MARKER="<!-- agent-lite:start -->"
END_MARKER="<!-- agent-lite:end -->"
EXCLUDE_START_MARKER="# agent-lite:start"
EXCLUDE_END_MARKER="# agent-lite:end"

TARGET_DIR=""
ACTION="install"
DRY_RUN=false
USE_SYMLINK=false
CLAUDE_COMPAT=false
GIT_EXCLUDE=false
ALL_SKILLS=false
WITH_SKILLS=()
AVAILABLE_SKILLS=()
SELECTED_SKILLS=()
UNINSTALL_SKILLS=()
RESOLVED_EXCLUDE_FILE=""

usage() {
  cat <<'EOF'
Usage: ./install.sh [OPTIONS] <project-dir>

Install or remove agent-lite in an individual project directory.

Options:
  --with <skills>  Also install optional skill(s), comma-separated or repeatable
                   (e.g., --with dev-python,aws-iac)
  --all-skills     Install all available skills instead of core skills only
  --uninstall      Remove agent-lite rules block and installed skills from <project-dir>
  --claude         Also link CLAUDE.md -> AGENTS.md (if absent) and .claude/skills/<skill>
  --symlink        Symlink skill folders instead of copying them
  --git-exclude    Add installed agent-lite paths to git info/exclude
  --dry-run        Show what would be changed without modifying files
  -h, --help       Show this help message

Examples:
  ./install.sh /path/to/my-project
  ./install.sh --with dev-python,aws-iac /path/to/my-project
  ./install.sh --all-skills --claude --git-exclude /path/to/my-project
  ./install.sh --uninstall /path/to/my-project
EOF
}

log() {
  printf '%s\n' "$*"
}

array_contains() {
  local needle="$1"
  shift
  local item
  for item in "$@"; do
    if [[ "$item" == "$needle" ]]; then
      return 0
    fi
  done
  return 1
}

discover_available_skills() {
  local skill_file skill_name
  local -a found=()
  while IFS= read -r skill_file; do
    [[ -n "$skill_file" ]] || continue
    skill_name="$(basename "$(dirname "$skill_file")")"
    found+=("$skill_name")
  done < <(
    shopt -s nullglob
    for skill_file in "$SCRIPT_DIR"/skills/*/SKILL.md; do
      printf '%s\n' "$skill_file"
    done | LC_ALL=C sort
  )
  AVAILABLE_SKILLS=("${found[@]+"${found[@]}"}")
}

add_with_skills() {
  local raw="$1"
  local item
  local -a parts=()

  if [[ -z "$raw" || "$raw" == ,* || "$raw" == *, ]]; then
    printf 'Error: invalid --with skill list: %s\n' "$raw" >&2
    exit 1
  fi

  IFS=',' read -r -a parts <<< "$raw"
  for item in "${parts[@]+"${parts[@]}"}"; do
    if [[ -z "$item" ]]; then
      printf 'Error: empty skill name in --with argument: %s\n' "$raw" >&2
      exit 1
    fi
    WITH_SKILLS+=("$item")
  done
}

validate_with_skills() {
  local skill
  local available_str="${AVAILABLE_SKILLS[*]:-(none)}"
  for skill in "${WITH_SKILLS[@]+"${WITH_SKILLS[@]}"}"; do
    if ! array_contains "$skill" "${AVAILABLE_SKILLS[@]+"${AVAILABLE_SKILLS[@]}"}"; then
      printf 'Error: unknown skill "%s". Available skills: %s\n' "$skill" "$available_str" >&2
      exit 1
    fi
  done
}

build_skill_lists() {
  local skill
  SELECTED_SKILLS=()
  UNINSTALL_SKILLS=()

  if $ALL_SKILLS; then
    SELECTED_SKILLS=("${AVAILABLE_SKILLS[@]+"${AVAILABLE_SKILLS[@]}"}")
  else
    for skill in "${CORE_SKILLS[@]}"; do
      if array_contains "$skill" "${AVAILABLE_SKILLS[@]+"${AVAILABLE_SKILLS[@]}"}"; then
        SELECTED_SKILLS+=("$skill")
      fi
    done
    for skill in "${WITH_SKILLS[@]+"${WITH_SKILLS[@]}"}"; do
      if ! array_contains "$skill" "${SELECTED_SKILLS[@]+"${SELECTED_SKILLS[@]}"}"; then
        SELECTED_SKILLS+=("$skill")
      fi
    done
  fi

  for skill in "${AVAILABLE_SKILLS[@]+"${AVAILABLE_SKILLS[@]}"}" "${LEGACY_SKILLS[@]}"; do
    if ! array_contains "$skill" "${UNINSTALL_SKILLS[@]+"${UNINSTALL_SKILLS[@]}"}"; then
      UNINSTALL_SKILLS+=("$skill")
    fi
  done
}

validate_markers() {
  local file="$1"
  local start="$2"
  local end="$3"

  [[ -f "$file" ]] || return 0

  local err_msg=""
  if ! err_msg="$(awk -v start="$start" -v end="$end" '
    $0 == start {
      start_count++
      if (start_line == 0) start_line = NR
    }
    $0 == end {
      end_count++
      if (end_line == 0) end_line = NR
    }
    END {
      if (start_count == 0 && end_count == 0) exit 0
      if (start_count != end_count) {
        if (start_count > end_count) print "unpaired start marker (" start ")"
        else print "unpaired end marker (" end ")"
        exit 2
      }
      if (start_count > 1) {
        print "multiple marker blocks found (" start ")"
        exit 2
      }
      if (end_line < start_line) {
        print "end marker appears before start marker"
        exit 2
      }
      exit 0
    }
  ' "$file")"; then
    printf 'Error: malformed markers in %s: %s\n' "$file" "$err_msg" >&2
    exit 1
  fi
}

strip_block_from_file() {
  local file="$1"
  local start="$2"
  local end="$3"
  local remove_if_empty="${4:-true}"

  validate_markers "$file" "$start" "$end"

  local tmp_file
  tmp_file="$(mktemp)"
  awk -v start="$start" -v end="$end" '
    $0 == start { skipping = 1; next }
    $0 == end { skipping = 0; next }
    !skipping {
      lines[++n] = $0
    }
    END {
      while (n > 0 && lines[n] ~ /^[[:space:]]*$/) {
        n--
      }
      for (i = 1; i <= n; i++) {
        print lines[i]
      }
    }
  ' "$file" > "$tmp_file"

  if [[ ! -s "$tmp_file" ]]; then
    rm -f "$tmp_file"
    if [[ "$remove_if_empty" == "true" ]]; then
      rm -f "$file"
    else
      : > "$file"
    fi
    return 0
  fi

  cat "$tmp_file" > "$file"
  rm -f "$tmp_file"
}

trim_trailing_blank_lines() {
  local file="$1"
  local tmp_file
  tmp_file="$(mktemp)"
  awk '
    { lines[++n] = $0 }
    END {
      while (n > 0 && lines[n] ~ /^[[:space:]]*$/) {
        n--
      }
      for (i = 1; i <= n; i++) {
        print lines[i]
      }
    }
  ' "$file" > "$tmp_file"

  if [[ ! -s "$tmp_file" ]]; then
    rm -f "$tmp_file"
    : > "$file"
    return 0
  fi

  cat "$tmp_file" > "$file"
  rm -f "$tmp_file"
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

  validate_markers "$TARGET_AGENTS" "$START_MARKER" "$END_MARKER"

  if grep -Fxq -- "$START_MARKER" "$TARGET_AGENTS"; then
    if $DRY_RUN; then
      log "[dry-run] Update existing agent-lite block in $TARGET_AGENTS"
      return
    fi
    strip_block_from_file "$TARGET_AGENTS" "$START_MARKER" "$END_MARKER" "false"
    if [[ -s "$TARGET_AGENTS" ]]; then
      {
        printf '\n'
        cat "$src"
      } >> "$TARGET_AGENTS"
    else
      cat "$src" > "$TARGET_AGENTS"
    fi
    log "Updated agent-lite block in $TARGET_AGENTS"
  else
    if $DRY_RUN; then
      log "[dry-run] Append agent-lite block to $TARGET_AGENTS"
      return
    fi
    trim_trailing_blank_lines "$TARGET_AGENTS"
    if [[ -s "$TARGET_AGENTS" ]]; then
      {
        printf '\n'
        cat "$src"
      } >> "$TARGET_AGENTS"
    else
      cat "$src" > "$TARGET_AGENTS"
    fi
    log "Appended agent-lite block to $TARGET_AGENTS"
  fi
}

install_skill() {
  local skill="$1"
  local src="$SCRIPT_DIR/skills/$skill"
  local dst="$TARGET_SKILLS_DIR/$skill"
  local claude_skills_dir="$TARGET_DIR/.claude/skills"
  local claude_dst="$claude_skills_dir/$skill"

  if $DRY_RUN; then
    if $USE_SYMLINK; then
      log "[dry-run] Link skill: $dst -> $src"
    else
      log "[dry-run] Install skill: $dst"
    fi
    if $CLAUDE_COMPAT; then
      log "[dry-run] Link Claude skill: $claude_dst -> ../../.agents/skills/$skill"
    fi
    return
  fi

  mkdir -p "$TARGET_SKILLS_DIR"
  if [[ -e "$dst" || -L "$dst" ]]; then
    rm -rf "$dst"
  fi

  if $USE_SYMLINK; then
    ln -s "$src" "$dst"
    log "Linked skill: $dst -> $src"
  else
    cp -R "$src" "$dst"
    log "Installed skill: $dst"
  fi

  if $CLAUDE_COMPAT; then
    mkdir -p "$claude_skills_dir"
    if [[ -e "$claude_dst" || -L "$claude_dst" ]]; then
      rm -rf "$claude_dst"
    fi
    ln -s "../../.agents/skills/$skill" "$claude_dst"
    log "Linked Claude skill: $claude_dst"
  fi
}

resolve_git_exclude_file() {
  local mode="${1:-verbose}"
  RESOLVED_EXCLUDE_FILE=""

  if ! command -v git >/dev/null 2>&1; then
    if [[ "$mode" != "quiet" ]]; then
      log "Note: git command not found; skipping --git-exclude"
    fi
    return 0
  fi

  local toplevel
  if ! toplevel="$(git -C "$TARGET_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
    if [[ "$mode" != "quiet" ]]; then
      log "Note: $TARGET_DIR is not a git repository; skipping --git-exclude"
    fi
    return 0
  fi

  local target_real toplevel_real
  target_real="$(cd "$TARGET_DIR" && pwd -P)"
  toplevel_real="$(cd "$toplevel" && pwd -P)"
  if [[ "$toplevel_real" != "$target_real" ]]; then
    if [[ "$mode" != "quiet" ]]; then
      log "Note: $TARGET_DIR is inside parent git repo ($toplevel); skipping --git-exclude"
    fi
    return 0
  fi

  local git_exclude_path
  git_exclude_path="$(git -C "$TARGET_DIR" rev-parse --git-path info/exclude)"
  if [[ "$git_exclude_path" == /* ]]; then
    RESOLVED_EXCLUDE_FILE="$git_exclude_path"
  else
    RESOLVED_EXCLUDE_FILE="$TARGET_DIR/$git_exclude_path"
  fi
}

upsert_git_exclude() {
  resolve_git_exclude_file "verbose"
  [[ -n "$RESOLVED_EXCLUDE_FILE" ]] || return 0

  if [[ -f "$RESOLVED_EXCLUDE_FILE" ]]; then
    validate_markers "$RESOLVED_EXCLUDE_FILE" "$EXCLUDE_START_MARKER" "$EXCLUDE_END_MARKER"
    validate_markers "$RESOLVED_EXCLUDE_FILE" "$START_MARKER" "$END_MARKER"
  fi

  if $DRY_RUN; then
    log "[dry-run] Update $RESOLVED_EXCLUDE_FILE"
    return
  fi

  mkdir -p "$(dirname "$RESOLVED_EXCLUDE_FILE")"
  touch "$RESOLVED_EXCLUDE_FILE"

  strip_block_from_file "$RESOLVED_EXCLUDE_FILE" "$EXCLUDE_START_MARKER" "$EXCLUDE_END_MARKER" "false"
  strip_block_from_file "$RESOLVED_EXCLUDE_FILE" "$START_MARKER" "$END_MARKER" "false"

  local -a entries=()
  if git -C "$TARGET_DIR" ls-files --error-unmatch AGENTS.md >/dev/null 2>&1; then
    log "Note: AGENTS.md is already tracked by git; leaving it out of $RESOLVED_EXCLUDE_FILE"
  else
    entries+=("AGENTS.md")
  fi

  local skill
  for skill in "${SELECTED_SKILLS[@]+"${SELECTED_SKILLS[@]}"}"; do
    entries+=(".agents/skills/$skill/")
  done

  if $CLAUDE_COMPAT; then
    local claude_md="$TARGET_DIR/CLAUDE.md"
    if ! git -C "$TARGET_DIR" ls-files --error-unmatch CLAUDE.md >/dev/null 2>&1; then
      if [[ ! -e "$claude_md" && ! -L "$claude_md" ]] || { [[ -L "$claude_md" ]] && [[ "$(readlink "$claude_md")" == "AGENTS.md" ]]; }; then
        entries+=("CLAUDE.md")
      fi
    fi
    for skill in "${SELECTED_SKILLS[@]+"${SELECTED_SKILLS[@]}"}"; do
      entries+=(".claude/skills/$skill")
    done
  fi

  local tmp_block
  tmp_block="$(mktemp)"
  {
    printf '%s\n' "$EXCLUDE_START_MARKER"
    local entry
    for entry in "${entries[@]+"${entries[@]}"}"; do
      printf '%s\n' "$entry"
    done
    printf '%s\n' "$EXCLUDE_END_MARKER"
  } > "$tmp_block"

  if [[ -s "$RESOLVED_EXCLUDE_FILE" ]]; then
    {
      printf '\n'
      cat "$tmp_block"
    } >> "$RESOLVED_EXCLUDE_FILE"
  else
    cat "$tmp_block" > "$RESOLVED_EXCLUDE_FILE"
  fi
  rm -f "$tmp_block"
  log "Updated $RESOLVED_EXCLUDE_FILE"
}

do_install() {
  upsert_agents_md

  local skill
  for skill in "${SELECTED_SKILLS[@]+"${SELECTED_SKILLS[@]}"}"; do
    install_skill "$skill"
  done

  if $CLAUDE_COMPAT; then
    local claude_md="$TARGET_DIR/CLAUDE.md"
    if [[ ! -e "$claude_md" && ! -L "$claude_md" ]]; then
      if $DRY_RUN; then
        log "[dry-run] Link $claude_md -> AGENTS.md"
      else
        ln -s "AGENTS.md" "$claude_md"
        log "Linked $claude_md -> AGENTS.md"
      fi
    else
      log "Note: $claude_md already exists; left untouched"
    fi
  fi

  if $GIT_EXCLUDE; then
    upsert_git_exclude
  fi

  if $DRY_RUN; then
    log "[dry-run] No files were modified in $TARGET_DIR"
  else
    log "Done. agent-lite is installed in $TARGET_DIR"
  fi
}

do_uninstall() {
  if [[ -f "$TARGET_AGENTS" ]]; then
    validate_markers "$TARGET_AGENTS" "$START_MARKER" "$END_MARKER"
    if grep -Fxq -- "$START_MARKER" "$TARGET_AGENTS"; then
      if $DRY_RUN; then
        log "[dry-run] Remove agent-lite block from $TARGET_AGENTS"
      else
        strip_block_from_file "$TARGET_AGENTS" "$START_MARKER" "$END_MARKER" "true"
        if [[ ! -f "$TARGET_AGENTS" ]]; then
          log "Removed empty $TARGET_AGENTS"
        else
          log "Removed agent-lite block from $TARGET_AGENTS"
        fi
      fi
    fi
  fi

  local skill dst claude_dst
  for skill in "${UNINSTALL_SKILLS[@]+"${UNINSTALL_SKILLS[@]}"}"; do
    dst="$TARGET_SKILLS_DIR/$skill"
    if [[ -e "$dst" || -L "$dst" ]]; then
      if $DRY_RUN; then
        log "[dry-run] Remove skill: $dst"
      else
        rm -rf "$dst"
        log "Removed skill: $dst"
      fi
    fi
    claude_dst="$TARGET_DIR/.claude/skills/$skill"
    if [[ -L "$claude_dst" ]]; then
      if $DRY_RUN; then
        log "[dry-run] Remove Claude skill link: $claude_dst"
      else
        rm -f "$claude_dst"
        log "Removed Claude skill link: $claude_dst"
      fi
    fi
  done

  if ! $DRY_RUN; then
    rmdir "$TARGET_SKILLS_DIR" 2>/dev/null || true
    rmdir "$TARGET_DIR/.agents" 2>/dev/null || true
    rmdir "$TARGET_DIR/.claude/skills" 2>/dev/null || true
    rmdir "$TARGET_DIR/.claude" 2>/dev/null || true
  fi

  local claude_md="$TARGET_DIR/CLAUDE.md"
  if [[ -L "$claude_md" ]] && [[ "$(readlink "$claude_md")" == "AGENTS.md" ]]; then
    if $DRY_RUN; then
      log "[dry-run] Remove symlink $claude_md"
    else
      rm -f "$claude_md"
      log "Removed symlink $claude_md"
    fi
  fi

  resolve_git_exclude_file "quiet"
  if [[ -n "$RESOLVED_EXCLUDE_FILE" && -f "$RESOLVED_EXCLUDE_FILE" ]]; then
    validate_markers "$RESOLVED_EXCLUDE_FILE" "$EXCLUDE_START_MARKER" "$EXCLUDE_END_MARKER"
    validate_markers "$RESOLVED_EXCLUDE_FILE" "$START_MARKER" "$END_MARKER"
    if grep -Fxq -- "$EXCLUDE_START_MARKER" "$RESOLVED_EXCLUDE_FILE" || grep -Fxq -- "$START_MARKER" "$RESOLVED_EXCLUDE_FILE"; then
      if $DRY_RUN; then
        log "[dry-run] Remove agent-lite block from $RESOLVED_EXCLUDE_FILE"
      else
        strip_block_from_file "$RESOLVED_EXCLUDE_FILE" "$EXCLUDE_START_MARKER" "$EXCLUDE_END_MARKER" "false"
        strip_block_from_file "$RESOLVED_EXCLUDE_FILE" "$START_MARKER" "$END_MARKER" "false"
        log "Removed agent-lite block from $RESOLVED_EXCLUDE_FILE"
      fi
    fi
  fi

  if $DRY_RUN; then
    log "[dry-run] No files were modified in $TARGET_DIR"
  else
    log "Done. agent-lite removed from $TARGET_DIR"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --with)
      if [[ $# -lt 2 || -z "$2" || "$2" == -* ]]; then
        printf 'Error: --with requires a skill name (or comma-separated list).\n' >&2
        exit 1
      fi
      add_with_skills "$2"
      shift 2
      ;;
    --with=*)
      add_with_skills "${1#--with=}"
      shift
      ;;
    --all-skills)
      ALL_SKILLS=true
      shift
      ;;
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

if [[ "$(cd "$TARGET_DIR" && pwd -P)" == "$(cd "$SCRIPT_DIR" && pwd -P)" ]]; then
  printf 'Error: refusing to install or uninstall inside the agent-lite source directory (%s).\n' "$SCRIPT_DIR" >&2
  exit 1
fi

TARGET_AGENTS="$TARGET_DIR/AGENTS.md"
TARGET_SKILLS_DIR="$TARGET_DIR/.agents/skills"

discover_available_skills
validate_with_skills
build_skill_lists

if [[ "$ACTION" == "install" ]]; then
  do_install
else
  do_uninstall
fi
