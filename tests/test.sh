#!/usr/bin/env bash
# Behavioral regression suite; no package manager or additional test framework.
set -euo pipefail
repo_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
command -v starship >/dev/null || { printf 'Install Starship before running tests.\n' >&2; exit 1; }
sandbox=$(mktemp -d "${TMPDIR:-/tmp}/starship-tests.XXXXXXXX")
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/home" "$sandbox/config" "$sandbox/cache" "$sandbox/work tree"
export STARSHIP_CONFIG=$sandbox/config/starship.toml
export STARSHIP_CACHE=$sandbox/cache
export XDG_CONFIG_HOME=$sandbox/config
export KUBECONFIG=$sandbox/no-kube-config
passed=0
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { passed=$((passed + 1)); printf 'PASS: %s\n' "$*"; }
contains() { grep -F -- "$2" "$1" >/dev/null || fail "$1 should contain: $2"; }
reject() {
  if "$@" > "$sandbox/rejected.log" 2>&1; then fail "Unexpected success: $*"; fi
}
switch() { bash "$repo_dir/activate.sh" "$@"; }
installer() {
  env HOME="$sandbox/home" ZDOTDIR="$sandbox/home" SHELL=/bin/zsh bash "$repo_dir/install.sh" "$@"
}
install_kit() {
  installer --install-dir "$sandbox/installed kit" \
    --config-file "$sandbox/config/installed.toml" "$@"
}
assert_choice() {
  contains "$1" "# Style $2;"
  contains "$1" "palette = '$3'"
}

cd "$sandbox/work tree"
for file in "$repo_dir/activate.sh" "$repo_dir/shell-functions.sh" "$repo_dir/install.sh" "$repo_dir"/lib/*.sh; do
  bash -n "$file"
done
pass 'All shell scripts parse with Bash'

printf '\n\n' | switch > "$sandbox/interactive.log"
assert_choice "$STARSHIP_CONFIG" C2 dracula_dark
switch --style A --palette ocean > /dev/null
switch --palette halloween > /dev/null
assert_choice "$STARSHIP_CONFIG" A halloween
switch --style D > /dev/null
assert_choice "$STARSHIP_CONFIG" D halloween
switch --palette 'Dracula Dark' > /dev/null
assert_choice "$STARSHIP_CONFIG" D dracula_dark
switch --palette dracula_dusk > /dev/null
assert_choice "$STARSHIP_CONFIG" D dracula_dark
pass 'Interactive defaults, independent selection, friendly names, and legacy alias'

switch --style C --palette nord --output "$sandbox/separate.toml" > /dev/null
switch --output "$sandbox/separate.toml" --palette christmas > /dev/null
assert_choice "$sandbox/separate.toml" C christmas
assert_choice "$STARSHIP_CONFIG" D dracula_dark
sed "s/palette = 'christmas'/palette = \"christmas\"/" "$sandbox/separate.toml" > "$sandbox/double.toml"
switch --output "$sandbox/double.toml" --style A > /dev/null
assert_choice "$sandbox/double.toml" A christmas
pass 'Explicit output retains its own choice, including double-quoted palette'

cp "$STARSHIP_CONFIG" "$sandbox/before.toml"
for args in '--style INVALID' '--palette INVALID' '--unknown' '--style' '--palette' '--output'; do
  # These fixed cases intentionally contain no shell metacharacters or spaces in values.
  reject switch $args
  cmp "$STARSHIP_CONFIG" "$sandbox/before.toml" || fail 'Invalid input changed the config'
done
switch --list > "$sandbox/list.log"
switch --help > "$sandbox/help.log"
contains "$sandbox/list.log" 'C2 (default)'
cmp "$STARSHIP_CONFIG" "$sandbox/before.toml"
pass 'Invalid arguments, help, and listing leave the prompt untouched'

switch --palette obsidian > "$sandbox/backup.log"
backup=$(sed -n 's/^Backup: //p' "$sandbox/backup.log")
cmp "$backup" "$sandbox/before.toml" || fail 'Backup contents differ'
ln -s "$STARSHIP_CONFIG" "$sandbox/link.toml"
switch --output "$sandbox/link.toml" --palette mocha > /dev/null
[[ -L "$sandbox/link.toml" ]] || fail 'Symlink was replaced'
assert_choice "$STARSHIP_CONFIG" D mocha
ln -s "$sandbox/new target.toml" "$sandbox/dangling.toml"
switch --output "$sandbox/dangling.toml" --style C > /dev/null
[[ -L "$sandbox/dangling.toml" && -f "$sandbox/new target.toml" ]] || fail 'Dangling link not preserved'
pass 'Backups contain original bytes; regular and dangling config symlinks survive'

cp "$repo_dir/configs/C2.toml" "$sandbox/library-before.toml"
reject switch --style A --output "$repo_dir/configs/C2.toml"
ln -s "$repo_dir/configs/C2.toml" "$sandbox/library-link.toml"
reject switch --style A --output "$sandbox/library-link.toml"
reject switch --output "$repo_dir/configs/../README.md"
reject switch --output "$sandbox"
ln -s "$sandbox/loop-b" "$sandbox/loop-a"
ln -s "$sandbox/loop-a" "$sandbox/loop-b"
reject switch --output "$sandbox/loop-a"
cmp "$repo_dir/configs/C2.toml" "$sandbox/library-before.toml"
pass 'Source package, symlink aliases, directories, and symlink loops are protected'

cp "$STARSHIP_CONFIG" "$sandbox/before.toml"
switch --style C2 --palette aurora --preview > "$sandbox/preview.log" 2> "$sandbox/preview.err"
[[ ! -s "$sandbox/preview.err" ]] || { cat "$sandbox/preview.err" >&2; fail 'Preview emitted diagnostics'; }
contains "$sandbox/preview.log" 'Preview: style C2 / palette aurora'
cmp "$STARSHIP_CONFIG" "$sandbox/before.toml"
pass 'Preview renders with Starship and leaves active config untouched'

bash -c 'source "$1/shell-functions.sh"; starship-theme --list' _ "$repo_dir" > "$sandbox/bash.log"
contains "$sandbox/bash.log" 'C2 (default)'
if command -v zsh >/dev/null; then
  zsh -f -c 'source "$1/shell-functions.sh"; starship-theme --list' _ "$repo_dir" > "$sandbox/zsh.log"
  contains "$sandbox/zsh.log" 'C2 (default)'
  pass 'The same function can be sourced by Bash and Zsh'
else
  pass 'Bash function works (Zsh unavailable; Zsh check skipped)'
fi

reject install_kit --palette invalid
[[ ! -e "$sandbox/installed kit" ]] || fail 'Invalid install created library'
install_kit --style C2 --palette dracula_dark > "$sandbox/install.log"
assert_choice "$sandbox/config/installed.toml" C2 dracula_dark
[[ -f "$sandbox/installed kit/configs/D.toml" ]] || fail 'Missing installed style'
contains "$sandbox/install.log" 'source '
bash -c 'source "$1/shell-functions.sh"; starship-theme --output "$2" --style A --palette ocean' \
  _ "$sandbox/installed kit" "$sandbox/config/installed.toml" > /dev/null
printf 'keep me\n' > "$sandbox/installed kit/user-notes.txt"
cp "$sandbox/installed kit/activate.sh" "$sandbox/old-activate.sh"
install_kit > "$sandbox/update.log"
assert_choice "$sandbox/config/installed.toml" A ocean
contains "$sandbox/installed kit/user-notes.txt" 'keep me'
backup=$(sed -n '\|^Backup: .*installed kit/activate.sh.backup.|s/^Backup: //p' "$sandbox/update.log")
cmp "$backup" "$sandbox/old-activate.sh"
pass 'Install and update work in paths with spaces, preserve selections and custom files, and back up managed files'

reject installer --install-dir "$repo_dir"
reject installer --install-dir "$repo_dir/new-kit"
reject installer --install-dir "$(dirname "$repo_dir")"
reject install_kit --config-file "$sandbox/installed kit/configs/C.toml"
reject install_kit --config-file "$sandbox"
ln -s "$repo_dir/configs/A.toml" "$sandbox/config/source-link.toml"
reject install_kit --config-file "$sandbox/config/source-link.toml"
mv "$sandbox/installed kit/activate.sh" "$sandbox/installed-activate.sh"
ln -s "$sandbox/installed-activate.sh" "$sandbox/installed kit/activate.sh"
reject install_kit
pass 'Installer rejects overlapping source/config paths and individual managed symlinks'

STARSHIP_CONFIG= XDG_CONFIG_HOME="$sandbox/xdg config" installer > /dev/null
assert_choice "$sandbox/xdg config/starship.toml" C2 dracula_dark
[[ -f "$sandbox/xdg config/starship-themes/shell-functions.sh" ]] || fail 'XDG installation missing'
ln -s "$sandbox/custom-active.toml" "$sandbox/active-link.toml"
STARSHIP_CONFIG="$sandbox/active-link.toml" XDG_CONFIG_HOME="$sandbox/xdg config" \
  installer --style C --palette nord > /dev/null
[[ -L "$sandbox/active-link.toml" ]] || fail 'Installer replaced active config symlink'
assert_choice "$sandbox/custom-active.toml" C nord
pass 'Installer respects XDG_CONFIG_HOME and STARSHIP_CONFIG, including symlink targets'

# Verify startup configuration rather than only the installed script files.
mkdir -p "$sandbox/zsh home"
printf '%s\n' '# keep my settings' 'export MY_SETTING=retained' 'eval "$(starship init zsh)"' > "$sandbox/zsh-original"
ln -s "$sandbox/zsh-original" "$sandbox/zsh home/.zshrc"
env HOME="$sandbox/zsh home" ZDOTDIR="$sandbox/zsh home" SHELL=/bin/zsh \
  bash "$repo_dir/install.sh" --install-dir "$sandbox/zsh kit" --config-file "$sandbox/zsh active.toml" > /dev/null
[[ -L "$sandbox/zsh home/.zshrc" ]] || fail 'Startup symlink was replaced'
contains "$sandbox/zsh-original" 'export MY_SETTING=retained'
[[ $(grep -c 'starship init zsh' "$sandbox/zsh-original") -eq 1 ]] || fail 'Duplicated existing initialization'
cp "$sandbox/zsh-original" "$sandbox/zsh-first-install"
env HOME="$sandbox/zsh home" ZDOTDIR="$sandbox/zsh home" SHELL=/bin/zsh \
  bash "$repo_dir/install.sh" --install-dir "$sandbox/zsh kit" --config-file "$sandbox/zsh active.toml" > /dev/null
cmp "$sandbox/zsh-original" "$sandbox/zsh-first-install" || fail 'Reinstall changed or duplicated shell setup'
if command -v zsh >/dev/null; then
  env HOME="$sandbox/zsh home" TERM=xterm-256color zsh -f -c 'source "$1"; starship-theme --palette halloween' \
    _ "$sandbox/zsh home/.zshrc" > /dev/null 2> "$sandbox/zsh-startup.err"
  [[ ! -s "$sandbox/zsh-startup.err" ]] || { cat "$sandbox/zsh-startup.err" >&2; fail 'Zsh startup emitted diagnostics'; }
  assert_choice "$sandbox/zsh active.toml" C2 halloween
fi
pass 'Zsh setup retains settings, initialization and symlinks; reinstall is idempotent; sourced switcher works'

mkdir -p "$sandbox/bash home"
printf '%s\n' 'export MY_PROFILE=retained' > "$sandbox/bash home/.profile"
env HOME="$sandbox/bash home" SHELL=/bin/bash bash "$repo_dir/install.sh" \
  --install-dir "$sandbox/bash kit" --config-file "$sandbox/bash active.toml" > /dev/null
[[ ! -e "$sandbox/bash home/.bash_profile" ]] || fail 'Installer shadowed the existing login profile'
contains "$sandbox/bash home/.profile" 'export MY_PROFILE=retained'
env HOME="$sandbox/bash home" TERM=xterm-256color bash --noprofile --norc -c 'source "$1"; starship-theme --palette ocean' \
  _ "$sandbox/bash home/.profile" > /dev/null 2> "$sandbox/bash-startup.err"
[[ ! -s "$sandbox/bash-startup.err" ]] || { cat "$sandbox/bash-startup.err" >&2; fail 'Bash startup emitted diagnostics'; }
assert_choice "$sandbox/bash active.toml" C2 ocean
pass 'Bash setup loads the switcher in login shells and retains an existing profile'

# Native Node detection must tolerate a briefly slow runtime without losing its version.
# Use a runtime on PATH, independent of workstation paths and project engine ranges.
mkdir -p "$sandbox/node project" "$sandbox/node runtime"
printf '%s\n' '{"engines":{"node":">=20.0.0"}}' > "$sandbox/node project/package.json"
cat > "$sandbox/node runtime/node" <<'NODE'
#!/bin/sh
sleep 1
printf 'v26.11.1\n'
NODE
chmod +x "$sandbox/node runtime/node"
for layout in C2 A C D; do
  switch --style "$layout" --output "$sandbox/node-theme.toml" > /dev/null
  (cd "$sandbox/node project" && env PATH="$sandbox/node runtime:$PATH" TERM=xterm-256color \
    STARSHIP_CONFIG="$sandbox/node-theme.toml" starship module nodejs) \
    > "$sandbox/node.out" 2> "$sandbox/node.err"
  [[ ! -s "$sandbox/node.err" ]] || { cat "$sandbox/node.err" >&2; fail "Delayed Node startup emitted diagnostics: $layout"; }
  contains "$sandbox/node.out" '26.11'
  (cd "$sandbox/work tree" && env PATH="$sandbox/node runtime:$PATH" TERM=xterm-256color \
    STARSHIP_CONFIG="$sandbox/node-theme.toml" starship module nodejs) \
    > "$sandbox/no-node.out" 2> "$sandbox/no-node.err"
  [[ ! -s "$sandbox/no-node.out" && ! -s "$sandbox/no-node.err" ]] || fail 'Node appeared outside a Node project'
done
pass 'All layouts tolerate slow Node startup, show the active runtime version, and hide Node outside matching projects'

# Render every style/palette with real Starship, including a dirty Git tree.
# Starship can return success for invalid TOML; any stderr diagnostic is a failure.
mkdir -p "$sandbox/git project"
git init -q "$sandbox/git project"
git -C "$sandbox/git project" symbolic-ref HEAD refs/heads/demo
printf 'original\n' > "$sandbox/git project/tracked.txt"
git -C "$sandbox/git project" add tracked.txt
git -C "$sandbox/git project" -c user.name='Theme Tests' -c user.email='tests@example.invalid' -c commit.gpgsign=false commit -qm fixture
git clone -q "$sandbox/git project" "$sandbox/clean project"
printf 'staged\n' > "$sandbox/git project/tracked.txt"
git -C "$sandbox/git project" add tracked.txt
printf 'modified\n' >> "$sandbox/git project/tracked.txt"
printf 'new\n' > "$sandbox/git project/untracked.txt"
palettes=(dracula_dark dracula aurora solar_flare velvet_gold obsidian mocha ocean nord daybreak halloween thanksgiving christmas new_year original_blue)
combinations=0
for style in C2 A C D; do
  for palette in "${palettes[@]}"; do
    switch --style "$style" --palette "$palette" --output "$sandbox/render.toml" > /dev/null
    for context in "$sandbox/work tree" "$sandbox/git project" "$sandbox/clean project"; do
      (cd "$context" && env HOME="$sandbox/home" TERM=xterm-256color STARSHIP_SHELL='' \
        STARSHIP_CONFIG="$sandbox/render.toml" starship prompt) > "$sandbox/prompt.ansi" 2> "$sandbox/prompt.err"
      [[ -s "$sandbox/prompt.ansi" ]] || fail "Empty prompt: $style/$palette"
      [[ ! -s "$sandbox/prompt.err" ]] || { cat "$sandbox/prompt.err" >&2; fail "Starship diagnostics: $style/$palette"; }
      if [[ "$context" == "$sandbox/git project" ]]; then
        contains "$sandbox/prompt.ansi" '●1'
        contains "$sandbox/prompt.ansi" '+1'
        contains "$sandbox/prompt.ansi" '?1'
      fi
    done
    combinations=$((combinations + 1))
  done
done
pass "$combinations combinations render without diagnostics in dirty Git, clean Git, and non-Git directories; Git counts match real changes"
printf '\n%s behavior groups passed.\n' "$passed"
