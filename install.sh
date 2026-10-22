#!/usr/bin/env bash
# Install/update a self-contained kit. Works with macOS Bash 3.2+.
set -euo pipefail
repo_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
source "$repo_dir/lib/files.sh"
config_home=${XDG_CONFIG_HOME:-$HOME/.config}
install_dir=$config_home/starship-themes
config_file=${STARSHIP_CONFIG:-$config_home/starship.toml}
selection=()
shell_name=${SHELL:-/bin/zsh}
shell_name=${shell_name##*/}
fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
while [[ $# -gt 0 ]]; do
  case "$1" in
    --install-dir|--config-file|--style|--palette|--shell)
      [[ $# -ge 2 && -n "$2" ]] || fail "$1 needs a value"
      case "$1" in
        --install-dir) install_dir=$2 ;;
        --config-file) config_file=$2 ;;
        --shell) shell_name=$2 ;;
        *) selection+=("$1" "$2") ;;
      esac
      shift 2 ;;
    --help|-h)
      printf '%s\n' 'Usage: ./install.sh [--shell zsh|bash] [--style C2|A|C|D] [--palette NAME]' \
        '                    [--install-dir DIR] [--config-file FILE]'
      exit 0 ;;
    *) fail "Unknown option: $1" ;;
  esac
done
case "$shell_name" in
  zsh) startup_files=("${ZDOTDIR:-$HOME}/.zshrc") ;;
  bash)
    startup_files=("$HOME/.bashrc")
    # Bash login shells read the first available file in this order.
    login_file=$HOME/.bash_profile
    for candidate in "$HOME/.bash_profile" "$HOME/.bash_login" "$HOME/.profile"; do
      if [[ -f "$candidate" ]]; then login_file=$candidate; break; fi
    done
    if [[ "$(theme_resolve_path "$login_file")" != "$(theme_resolve_path "$HOME/.bashrc")" ]]; then
      startup_files+=("$login_file")
    fi ;;
  *) fail 'Choose a supported shell with --shell zsh or --shell bash' ;;
esac

install_dir=$(theme_resolve_path "$install_dir")
config_target=$(theme_resolve_path "$config_file")
# No source overwrite, including an install into a parent of the source checkout.
case "$install_dir/" in "$repo_dir/"*) fail 'Install outside the source checkout' ;; esac
case "$repo_dir/" in "$install_dir/"*) fail 'Install directory cannot contain the source checkout' ;; esac
case "$config_target/" in "$repo_dir/"*|"$install_dir/"*) fail 'Keep the active config outside the source and installed theme packages' ;; esac
case "$install_dir/" in "$config_target/"*) fail 'The config file cannot be a parent of the install directory' ;; esac
[[ ! -d "$config_target" ]] || fail 'Config file is a directory'
[[ ! -e "$install_dir" || -d "$install_dir" ]] || fail 'Install directory is a file'

files=(activate.sh shell-functions.sh lib/files.sh configs/A.toml configs/C.toml configs/C2.toml configs/D.toml README.md LICENSE)
for file in "${files[@]}"; do
  [[ -f "$repo_dir/$file" ]] || fail "Missing package file: $file"
  target=$(theme_resolve_path "$install_dir/$file")
  # A dotfile manager may link the whole kit; refuse links on individual files.
  [[ "$target" == "$install_dir/$file" ]] || fail "Managed file is reached through a symlink: $file"
  [[ ! -d "$target" ]] || fail "Managed file is a directory: $file"
done
for startup in "${startup_files[@]}"; do
  target=$(theme_resolve_path "$startup")
  case "$target/" in "$repo_dir/"*|"$install_dir/"*) fail 'Keep shell startup files outside the theme library' ;; esac
  [[ "$target" != "$config_target" ]] || fail 'The prompt config and shell startup file must be different files'
  [[ ! -e "$target" || -f "$target" ]] || fail "Shell startup path is not a regular file: $startup"
done

# Render and validate the choice before changing the installed library or prompt.
staging=$(mktemp -d "${TMPDIR:-/tmp}/starship-install.XXXXXXXX")
trap 'rm -rf "$staging"' EXIT
if [[ -f "$config_target" ]]; then cp -p "$config_target" "$staging/starship.toml"; fi
# Bash 3.2 treats an empty array as unset under nounset; use the guarded expansion.
bash "$repo_dir/activate.sh" --output "$staging/starship.toml" ${selection[@]+"${selection[@]}"} > "$staging/selection.log"

# Replace only our managed block, retaining the rest of each startup file.
index=0
for startup in "${startup_files[@]}"; do
  prepared=$staging/startup.$index
  if [[ -f "$startup" ]]; then
    awk '
      $0 == "# >>> starship-themes >>>" { if (managed) exit 1; managed=1; next }
      $0 == "# <<< starship-themes <<<" { if (!managed) exit 1; managed=0; next }
      !managed { print }
      END { if (managed) exit 1 }
    ' "$startup" > "$prepared"
  else
    : > "$prepared"
  fi
  {
    printf '# >>> starship-themes >>>\n'
    if [[ $index -eq 0 ]]; then
      printf 'export STARSHIP_CONFIG=%q\n' "$config_target"
      # Keep an existing initialization rather than adding another invocation.
      if ! grep -E '^[[:space:]]*[^[:space:]#].*starship[[:space:]]+init[[:space:]]+'"$shell_name" "$prepared" >/dev/null; then
        printf 'if command -v starship >/dev/null 2>&1; then\n'
        printf '  eval "$(starship init %s)"\nfi\n' "$shell_name"
      fi
      printf 'source %q\n' "$install_dir/shell-functions.sh"
    else
      printf 'if [ -n "${BASH_VERSION-}" ] && ! declare -F starship-theme >/dev/null; then\n'
      printf '  . %q\nfi\n' "$HOME/.bashrc"
    fi
    printf '# <<< starship-themes <<<\n'
  } >> "$prepared"
  index=$((index + 1))
done

for file in "${files[@]}"; do
  theme_write_file "$repo_dir/$file" "$install_dir/$file"
done
theme_write_file "$staging/starship.toml" "$config_file"
index=0
for startup in "${startup_files[@]}"; do
  if [[ -f "$startup" ]]; then
    # Preserve startup file permissions, including through dotfile symlinks.
    cp -p "$startup" "$staging/startup-mode"
    cat "$staging/startup.$index" > "$staging/startup-mode"
    theme_write_file "$staging/startup-mode" "$startup"
  else
    theme_write_file "$staging/startup.$index" "$startup"
  fi
  printf 'Updated shell config: %s\n' "$startup"
  index=$((index + 1))
done
printf '\nInstalled theme kit: %s\nActive config: %s\n' "$install_dir" "$config_file"
LC_ALL=C awk '/^# Style / || /^palette[[:space:]]*=/' "$staging/starship.toml"
printf '\nOpen a new terminal, or reload now:\n'
printf '  source %q\n' "${startup_files[0]}"
printf '\nThen run: starship-theme\n'
printf 'Existing files have adjacent .backup.* copies.\n'
