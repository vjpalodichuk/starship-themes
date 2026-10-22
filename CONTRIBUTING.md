# Contributing

Use Bash 3.2+, Git, and Starship (tested with 1.26.0). Use a Nerd Font terminal to check the appearance.

1. Edit the canonical configs or Bash scripts. Keep common modules and palette definitions consistent across all four layouts.
2. Run `bash tests/test.sh`. Tests isolate installation and shell integration in temporary homes and render all sixty layout/palette combinations with actual Starship.
3. Review visual changes in a Nerd Font terminal. Preserve readable foreground/background combinations and continuous dividers when optional modules disappear.
4. Update README.md for changed behavior.

To try installation manually without affecting your own shell configuration:

```sh
test_home=$(mktemp -d)
env HOME="$test_home" ZDOTDIR="$test_home" \
  XDG_CONFIG_HOME="$test_home/.config" STARSHIP_CONFIG="$test_home/.config/starship.toml" \
  ./install.sh --shell zsh
```

Keep this repository focused on the theme files, picker, and installer. Do not add a build system or distribution archives. Do not hardcode workstation paths or add prompt-time helper processes.
