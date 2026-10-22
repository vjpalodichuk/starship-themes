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

# Back up contents, then atomically replace the resolved target. Keep symlinks.
theme_write_file() {
  local source=$1 destination=$2 target backup temporary
  target=$(theme_resolve_path "$destination") || return 1
  [[ ! -d "$target" ]] || { printf 'Error: destination is a directory: %s\n' "$destination" >&2; return 1; }
  mkdir -p "$(dirname "$target")" || return 1
  if [[ -e "$target" ]]; then
    backup=$(mktemp "$destination.backup.$(date '+%Y%m%d-%H%M%S').XXXXXXXX") || return 1
    cp -p "$target" "$backup" || return 1
    printf 'Backup: %s\n' "$backup"
  fi
  temporary=$(mktemp "$(dirname "$target")/.starship-write.XXXXXXXX") || return 1
  if ! cp -p "$source" "$temporary"; then rm -f "$temporary"; return 1; fi
  if ! mv -f "$temporary" "$target"; then rm -f "$temporary"; return 1; fi
}
