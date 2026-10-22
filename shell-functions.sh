# Source this file from ~/.zshrc (or ~/.bashrc); do not execute it.
# It finds activate.sh beside itself, so the whole folder can be moved together.
if [ -n "${ZSH_VERSION-}" ]; then
  _starship_theme_source="${(%):-%x}"
elif [ -n "${BASH_VERSION-}" ]; then
  _starship_theme_source="${BASH_SOURCE[0]}"
else
  printf '%s\n' 'Starship theme functions require Zsh or Bash.' >&2
  return 1
fi
STARSHIP_THEME_HOME=$(CDPATH= cd -- "$(dirname -- "$_starship_theme_source")" && pwd -P) || return 1
unset _starship_theme_source

starship-theme() {
  bash "$STARSHIP_THEME_HOME/activate.sh" "$@"
}
