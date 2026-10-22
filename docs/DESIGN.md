# Design and origin

The layouts and switcher were imported from the finished “Fix Starship prompt config” kit developed October 21, 2026.

- C2 with rounded ends and curved dividers is the default. A, C, and D remain available.
- Dracula Dark is the default palette; all fifteen palettes are included in each standalone TOML config.
- Git branch, status counts, and state share a section.
- Languages and build tools share a section. Native versions use `${major}(.${minor})`; static indicators have no invented versions.
- Docker and Kubernetes are icon-only. Kubernetes is enabled.
- The switcher is a callable Bash/Zsh function and runs only when requested.

`dracula` follows the [official Dracula palette](https://draculatheme.com/spec); `dracula_dark` uses darker tints. Bat is not a dependency.

`install.sh` copies the required files, activates the config, and updates shell integration. Shared file writes back up existing contents and preserve symlinks. A multi-file installation is not one atomic transaction; backups remain available if an I/O error interrupts an update.

The private conversation and personal workstation files are not included. The original recorded preview is documented in `previews/README.md`.
