#!/usr/bin/env bash
# Undo recorded installs while keeping settings outside our marked blocks.
set -euo pipefail
script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
source "$script_dir/lib/files.sh"
install_dir=${XDG_CONFIG_HOME:-$HOME/.config}/starship-themes
# An installed copy knows its location, including custom install directories.
if [[ -d "$script_dir/.install-state" ]]; then install_dir=$script_dir; fi
keep_config=false
fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
while [[ $# -gt 0 ]]; do
  case "$1" in
    --install-dir)
      [[ $# -ge 2 && -n "$2" ]] || fail '--install-dir needs a value'
      install_dir=$2; shift 2 ;;
    --keep-config) keep_config=true; shift ;;
    --help|-h)
      printf '%s\n' 'Usage: bash uninstall.sh [--install-dir DIR] [--keep-config]' \
        'Remove shell integration and installed files; restore the original Starship config.' \
        '--keep-config leaves the active config in place instead of restoring it.'
      exit 0 ;;
    *) fail "Unknown option: $1" ;;
  esac
done
install_dir=$(theme_resolve_path "$install_dir")
state_dir=$install_dir/.install-state
[[ -d "$state_dir" && ! -L "$state_dir" ]] || fail "No uninstall information at $install_dir"
staging=$(mktemp -d "${TMPDIR:-/tmp}/starship-uninstall.XXXXXXXX")
trap 'rm -rf "$staging"' EXIT
printf -v block_owner '# Theme library: %q' "$install_dir"

# Prepare every restoration before modifying anything. Hand-edited configs
# require an explicit choice; ordinary theme switching can always be undone.
entries=()
for entry in "$state_dir"/entry.*; do
  [[ -d "$entry" && ! -L "$entry" ]] || continue
  target=$(cat "$entry/path")
  kind=$(cat "$entry/kind")
  [[ "$target" == /* && "$(theme_resolve_path "$target")" == "$target" ]] || fail "Recorded path changed: $target"
  [[ ! -e "$target" || -f "$target" ]] || fail "Not a regular file: $target"
  case "$target/" in "$install_dir/"*) fail 'Recorded target overlaps the theme library' ;; esac
  prepared=$staging/${entry##*/}
  case "$kind" in
    startup)
      if [[ -f "$target" ]]; then
        cp -p "$target" "$prepared"
        theme_strip_integration "$target" "$block_owner" > "$prepared" || fail "Malformed integration block: $target"
      fi ;;
    config)
      if ! $keep_config && [[ -f "$target" ]]; then
        cp -p "$target" "$prepared"
        bash "$install_dir/activate.sh" --output "$prepared" > /dev/null
        cmp -s "$target" "$prepared" || fail "Config has personal edits: $target. Save it first, or use --keep-config."
      fi
      if [[ -e "$entry/existed" ]]; then
        [[ -f "$entry/original" ]] || fail "Missing original config for $target"
      fi ;;
    *) fail "Invalid uninstall record: $entry" ;;
  esac
  entries+=("$entry")
done
[[ ${#entries[@]} -gt 0 ]] || fail 'No uninstall records found'

# Remove only known package files. Unrelated notes and older backups survive.
files=(activate.sh uninstall.sh shell-functions.sh lib/files.sh configs/A.toml configs/C.toml configs/C2.toml configs/D.toml README.md LICENSE)
for file in "${files[@]}"; do
  [[ "$(theme_resolve_path "$install_dir/$file")" == "$install_dir/$file" ]] || fail "Managed file is reached through a symlink: $file"
  [[ ! -d "$install_dir/$file" ]] || fail "Managed file is a directory: $file"
done
for entry in "${entries[@]}"; do
  target=$(cat "$entry/path")
  case "$(cat "$entry/kind")" in
    startup)
      prepared=$staging/${entry##*/}
      if [[ -f "$prepared" ]]; then
        if [[ ! -e "$entry/existed" && ! -s "$prepared" ]]; then
          rm -f "$target"
        else
          theme_write_file "$prepared" "$target"
        fi
      fi ;;
    config)
      if ! $keep_config; then
        if [[ -e "$entry/existed" ]]; then
          theme_write_file "$entry/original" "$target"
        else
          rm -f "$target"
        fi
      fi ;;
  esac
done
for file in "${files[@]}"; do rm -f "$install_dir/$file"; done
rm -rf "$state_dir"
# Nonempty directories are intentionally retained.
for directory in "$install_dir/lib" "$install_dir/configs" "$install_dir"; do
  rmdir "$directory" 2>/dev/null || true
done
printf 'Uninstalled theme kit: %s\nOpen a new terminal to finish unloading shell integration.\n' "$install_dir"
