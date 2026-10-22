# Shared filesystem helpers. Bash 3.2+, with no external language runtime.

# Resolve missing paths and symlinks without GNU realpath (macOS compatible).
# Resolve each component before '..', as the filesystem does.
theme_resolve_path() {
  local remaining component resolved='' link hops=0
  case "$1" in /*) remaining=${1#/} ;; *) remaining=${PWD#/}/$1 ;; esac
  while [[ -n "$remaining" ]]; do
    component=${remaining%%/*}
    if [[ "$remaining" == */* ]]; then remaining=${remaining#*/}; else remaining=''; fi
    case "$component" in
      ''|.) continue ;;
      ..) resolved=${resolved%/*}; continue ;;
    esac
    resolved=$resolved/$component
    if [[ -L "$resolved" ]]; then
      hops=$((hops + 1))
      [[ $hops -le 40 ]] || { printf 'Error: symlink loop: %s\n' "$1" >&2; return 1; }
      link=$(readlink "$resolved") || return 1
      resolved=${resolved%/*}
      case "$link" in /*) resolved=''; link=${link#/} ;; esac
      remaining=$link${remaining:+/$remaining}
    fi
  done
  printf '%s\n' "${resolved:-/}"
}

# Atomically replace the resolved target, optionally backing up changed contents.
theme_write_file() {
  local source=$1 destination=$2 backup_requested=${3:-false} target backup temporary
  target=$(theme_resolve_path "$destination") || return 1
  [[ ! -d "$target" ]] || { printf 'Error: destination is a directory: %s\n' "$destination" >&2; return 1; }
  if [[ -f "$target" ]] && cmp -s "$source" "$target"; then return 0; fi
  mkdir -p "$(dirname "$target")" || return 1
  if [[ "$backup_requested" == true && -e "$target" ]]; then
    backup=$(mktemp "$destination.backup.$(date '+%Y%m%d-%H%M%S').XXXXXXXX") || return 1
    cp -p "$target" "$backup" || return 1
    printf 'Backup: %s\n' "$backup"
  fi
  temporary=$(mktemp "$(dirname "$target")/.starship-write.XXXXXXXX") || return 1
  if ! cp -p "$source" "$temporary"; then rm -f "$temporary"; return 1; fi
  if ! mv -f "$temporary" "$target"; then rm -f "$temporary"; return 1; fi
}

# Only the marked integration belongs to us; retain settings added around it.
theme_strip_integration() {
  THEME_BLOCK_OWNER=${2-} awk '
    $0 == "# >>> starship-themes >>>" {
      if (managed) exit 1
      managed=1; block=$0 ORS; owned=(ENVIRON["THEME_BLOCK_OWNER"] == ""); next
    }
    $0 == "# <<< starship-themes <<<" {
      if (!managed) exit 1
      if (!owned) printf "%s%s\n", block, $0
      managed=0; next
    }
    managed {
      block=block $0 ORS
      if ($0 == ENVIRON["THEME_BLOCK_OWNER"]) owned=1
      next
    }
    !managed { print }
    END { if (managed) exit 1 }
  ' "$1"
}

# Record each target once, across reinstalls and shell/config changes. Shell
# blocks can be removed structurally; only replaced prompt contents need saving.
theme_record_install() {
  local kind=$1 target=$2 state_dir=$3 entry pending
  for entry in "$state_dir"/entry.*; do
    [[ -d "$entry" ]] || continue
    if [[ "$(cat "$entry/path")" == "$target" ]]; then
      [[ "$(cat "$entry/kind")" == "$kind" ]] || return 1
      return 0
    fi
  done
  pending=$(mktemp -d "$state_dir/.pending.XXXXXXXX") || return 1
  printf '%s\n' "$target" > "$pending/path" || return 1
  printf '%s\n' "$kind" > "$pending/kind" || return 1
  if [[ -f "$target" ]]; then
    : > "$pending/existed"
    if [[ "$kind" == config ]]; then cp -p "$target" "$pending/original" || return 1; fi
  fi
  mv "$pending" "$state_dir/entry.${pending##*.}" || return 1
}
