# Agent guide

This repository contains standalone Starship TOML layouts, a Bash/Zsh theme switcher, and a Bash installer. Read README.md before editing.

- Keep the workflow simple: `./install.sh` installs and configures shell integration; `bash tests/test.sh` verifies it. Do not add a build system, archive packaging, Python, or other runtime dependencies.
- `configs/{A,C,C2,D}.toml` are canonical. Preserve UTF-8 icons and keep shared modules and all fifteen palettes consistent across the four files.
- Preserve C2 / Dracula Dark defaults, independent style/palette selection, grouped language icons with major/minor versions, Git counts, and icon-only Docker/Kubernetes unless asked to change them.
- Activated files must work directly with Starship. The picker must not run at each prompt.
- Support macOS Bash 3.2 and Linux Bash; the sourceable function must also work in Zsh. Avoid associative arrays and GNU-only utilities.
- Preserve config/startup symlinks, existing shell settings, backups, and paths with spaces. Replace only the installer's marked shell integration blocks on updates.
- Test installation using a temporary `HOME`, `ZDOTDIR`, `XDG_CONFIG_HOME`, and `STARSHIP_CONFIG`; never use the contributor's actual startup files for tests.
- Add behavioral regression coverage for substantive fixes. Treat Starship stderr diagnostics as failures even if it exits successfully.
- Keep generated artifacts, personal configs, chat transcripts, credentials, and machine-specific paths out of the repository.
- Update README.md for changes to installation, defaults, or usage.
- Leave the initial STAR-001 changes uncommitted until the user explicitly approves committing. Prefix the approved commit message with `STAR-001:`.

<!-- postman-cli:installation:start -->
Postman CLI is installed on this device, and can be used for API Engineering work.
<!-- postman-cli:installation:end -->
