# Design and origin

The layouts and switcher were imported from the finished “Fix Starship prompt config” kit developed October 21, 2026.

- C2 with rounded ends and curved dividers is the default. A, C, and D remain available.
- Dracula Dark is the default palette; all fifteen palettes are included in each standalone TOML config.
- Git branch, status counts, and state share a section.
- Languages and build tools share a section. Native versions use `${major}(.${minor})`; static indicators have no invented versions.
- Docker and Kubernetes are icon-only. Kubernetes is enabled.
- The switcher is a callable Bash/Zsh function and runs only when requested.

`dracula` follows the [official Dracula palette](https://draculatheme.com/spec); `dracula_dark` uses darker tints. Bat is not a dependency.

`install.sh` copies the required files, activates the config, and updates shell integration. Shared file writes preserve symlinks, skip unchanged files, and only create an adjacent backup when theme activation explicitly requests `--backup`.

The private installed `.install-state/` directory records each affected config/startup target once. Only an existing Starship config needs its original contents saved: activation replaces that whole file, so shell-style block removal cannot reconstruct it. Startup files need only path/existence metadata; uninstall removes blocks carrying the selected kit's identity, preserving surrounding settings. Reinstalls retain the original state. A multi-file install/uninstall is not one atomic transaction; state is recorded before installation writes, and uninstall validates all targets and prepares shell changes before writing. Personal edits to an active config stop uninstall unless `--keep-config` is selected.

The private conversation and personal workstation files are not included. The original recorded preview is documented in `previews/README.md`.
