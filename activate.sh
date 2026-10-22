#!/usr/bin/env bash
# Select a standalone Starship config. Compatible with macOS Bash 3.2+.
set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
source "$script_dir/lib/files.sh"
style=C2
palette=dracula_dark
style_requested=false
palette_requested=false
palette_names=(dracula_dark dracula aurora solar_flare velvet_gold obsidian mocha ocean nord daybreak halloween thanksgiving christmas new_year original_blue)
normalize_palette() {
  local normalized
  normalized=$(printf '%s' "$1" | LC_ALL=C tr '[:upper:] ' '[:lower:]_')
  case "$normalized" in dracula_dusk) normalized=dracula_dark ;; esac
  printf '%s\n' "$normalized"
}
palette_title() {
  case "$1" in
    dracula_dark) printf 'Dracula Dark' ;;
    dracula) printf 'Dracula' ;;
    solar_flare) printf 'Solar Flare' ;;
    velvet_gold) printf 'Velvet Gold' ;;
    new_year) printf "New Year's" ;;
    original_blue) printf 'Blue Ribbon' ;;
    *) printf '%s' "$1" | awk '{ print toupper(substr($0,1,1)) substr($0,2) }' ;;
  esac
}
valid_palette() {
  local candidate
  for candidate in "${palette_names[@]}"; do
    if [[ "$1" == "$candidate" ]]; then return 0; fi
  done
  return 1
}
action=activate
destination=${STARSHIP_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml}
interactive=false
if [[ $# -eq 0 ]]; then interactive=true; fi

usage() {
  cat <<'HELP'
Usage: ./activate.sh [--style C2|A|C|D] [--palette NAME] [--preview]
                    [--output FILE] [--list] [--help]

With no arguments, show the style and palette menus. Preserve the active
style/palette unless changed. New installations default to C2 / Dracula Dark.
--preview       Print the selected prompt in the current directory; do not activate.
--output FILE   Write to FILE instead of the active Starship configuration.

Examples:
  ./activate.sh
  ./activate.sh --style C2 --palette halloween --preview
  ./activate.sh --style A --palette ocean

Activation backs up an existing destination first. Starship reads the resulting
plain UTF-8 TOML file directly; this script does not run with each prompt.
HELP
}
fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
require_value() { [[ $# -ge 2 && -n "$2" ]] || fail "$1 needs a value"; }
while [[ $# -gt 0 ]]; do
  case "$1" in
    --style) require_value "$@"; style=$2; style_requested=true; shift 2 ;;
    --palette) require_value "$@"; palette=$(normalize_palette "$2"); palette_requested=true; shift 2 ;;
    --output) require_value "$@"; destination=$2; shift 2 ;;
    --preview) action=preview; shift ;;
    --list)
      printf '%s\n' 'Styles: C2 (default), A, C, D' \
        'Default palette: dracula_dark (Dracula Dark)' \
        'More section palettes: dracula, aurora, solar_flare, velvet_gold, obsidian' \
        'More everyday palettes: mocha, ocean, nord, daybreak' \
        'Seasonal palettes: halloween, thanksgiving, christmas, new_year' \
        'Blue section palette: original_blue'
      exit 0 ;;
    --help|-h) usage; exit 0 ;;
    *) fail "Unknown option: $1 (use --help)" ;;
  esac
done

# Read the final --output destination, so separate configs retain their own choices.
if [[ -f "$destination" ]]; then
  active_style=$(LC_ALL=C awk '/^# Style (C2|A|C|D);/ { gsub(/;/, "", $3); print $3; exit }' "$destination")
  active_palette=$(LC_ALL=C awk -F "['\"]" '/^palette[[:space:]]*=/ { print $2; exit }' "$destination")
  if ! $style_requested; then
    case "$active_style" in C2|A|C|D) style=$active_style ;; esac
  fi
  if ! $palette_requested; then
    active_palette=$(normalize_palette "$active_palette")
    if valid_palette "$active_palette"; then palette=$active_palette; fi
  fi
fi

if $interactive; then
  printf '%s\n' 'Choose a style:' '  1) C2 — rounded ends and curved dividers' \
    '  2) A  — pointed ends and chevron dividers' \
    '  3) C  — rounded ends and straight dividers' \
    '  4) D  — pointed ends and slash dividers'
  printf 'Style [%s]: ' "$style"
  IFS= read -r choice || fail 'No style selection received'
  case "${choice:-$style}" in
    1|C2|c2) style=C2 ;; 2|A|a) style=A ;; 3|C|c) style=C ;; 4|D|d) style=D ;;
    *) fail 'Choose 1, 2, 3, or 4' ;;
  esac
  printf '\n%s\n' 'Choose a palette:'
  menu_index=1
  for menu_palette in "${palette_names[@]}"; do
    printf '  %s) %s [%s]\n' "$menu_index" "$(palette_title "$menu_palette")" "$menu_palette"
    menu_index=$((menu_index + 1))
  done
  printf 'Palette [%s]: ' "$(palette_title "$palette")"
  IFS= read -r choice || fail 'No palette selection received'
  choice=$(normalize_palette "${choice:-$palette}")
  found=false
  menu_index=1
  for menu_palette in "${palette_names[@]}"; do
    if [[ "$choice" == "$menu_index" || "$choice" == "$menu_palette" ]]; then
      palette=$menu_palette
      found=true
      break
    fi
    menu_index=$((menu_index + 1))
  done
  $found || fail 'Choose a palette shown in the menu'

fi

case "$style" in C2|c2) style=C2 ;; A|a) style=A ;; C|c) style=C ;; D|d) style=D ;; *) fail "Unknown style: $style" ;; esac
valid_palette "$palette" || fail "Unknown palette: $palette"
source_config=$script_dir/configs/$style.toml
[[ -f "$source_config" ]] || fail "Missing style config: $source_config"

preview_file=$(mktemp "${TMPDIR:-/tmp}/starship-choice.XXXXXXXX")
trap 'rm -f "$preview_file"' EXIT
awk -v selected="$palette" '
  /^palette[[:space:]]*=/ { print "palette = \047" selected "\047"; next }
  { print }
' "$source_config" > "$preview_file"

if [[ "$action" == preview ]]; then
  command -v starship >/dev/null 2>&1 || fail 'Install Starship before previewing'
  preview_term=${TERM:-xterm-256color}
  if [[ "$preview_term" == dumb ]]; then preview_term=xterm-256color; fi
  printf 'Preview: style %s / palette %s\n\n' "$style" "$palette"
  TERM="$preview_term" STARSHIP_SHELL='' STARSHIP_CONFIG="$preview_file" starship prompt
  printf '\n'
  exit 0
fi

# Protect all package files, including paths reached through symlinks.
resolved_destination=$(theme_resolve_path "$destination")
case "$resolved_destination" in "$script_dir"|"$script_dir"/*) fail 'Choose a destination outside the theme package' ;; esac
theme_write_file "$preview_file" "$destination"
printf 'Activated: style %s / palette %s\nConfig: %s\n' "$style" "$palette" "$destination"
