# Starship Themes

Four Starship prompt layouts, fifteen color palettes, and a theme switcher for Bash and Zsh. **C2 + Dracula Dark** is the default. The layouts are plain UTF-8 TOML files read directly by Starship.

## Install

Install [Starship](https://starship.rs/guide/#installation) and enable a [Nerd Font](https://www.nerdfonts.com/) in your terminal. The installer supports macOS and Linux with Bash 3.2 or newer. The themes have been tested with Starship 1.26.0.

Clone this repository, enter the checkout, and run:

```sh
./install.sh
```

The installer uses your login shell (`$SHELL`), or you can select it explicitly:

```sh
./install.sh --shell zsh
./install.sh --shell bash
```

It will:

- Copy the four layout configs and switcher to `~/.config/starship-themes/`.
- Activate the theme in `~/.config/starship.toml`, preserving recognized existing style/palette choices. Fresh installs use C2 / Dracula Dark.
- Configure Starship and the `starship-theme` function in your shell startup file. Zsh uses `${ZDOTDIR:-$HOME}/.zshrc`. Bash uses `~/.bashrc` and ensures the existing login profile loads it.
- Back up existing configs and startup files to adjacent `.backup.TIMESTAMP.RANDOM` files. Existing config/startup symlinks are preserved.

Open a new terminal, or run the reload command printed by the installer. No manual editing of startup files is needed. Existing Starship initialization in the configured startup file is retained. Reinstalling replaces the installer's marked block without duplicating it or removing other shell settings.

The installer sets up the themes and shell integration; Starship itself and fonts are installed separately.

## Switch themes

```sh
starship-theme                                # Interactive layout and palette picker
starship-theme --palette halloween            # Keep the current layout
starship-theme --style A                      # Keep the current palette
starship-theme --style C2 --palette ocean
starship-theme --palette obsidian --preview   # Try without activating
starship-theme --list
```

Press Enter in the picker to keep the current selection. Changing themes backs up the active TOML before replacing it. The switcher runs when you select a theme, not on every prompt.

| Layout | Appearance |
| --- | --- |
| **C2** | Rounded ends and curved dividers (default) |
| A | Pointed ends and chevrons |
| C | Rounded ends and straight dividers |
| D | Pointed ends and slashes |

| Palettes | Names |
| --- | --- |
| Everyday | `dracula_dark`, `dracula`, `aurora`, `solar_flare`, `velvet_gold`, `obsidian`, `mocha`, `ocean`, `nord`, `daybreak` |
| Seasonal | `halloween`, `thanksgiving`, `christmas`, `new_year` |
| Original | `original_blue` |

Git branch/status share a section, with `●1` for a modified file, `+1` for a staged file, and `?1` for an untracked file. Languages and build tools share a section with icons and detected major/minor versions. Static framework indicators show icons only. Docker and Kubernetes are icon-only; Kubernetes is enabled when a context is detected.

## Update

```sh
git pull --ff-only
./install.sh
```

The installer refreshes the files and keeps recognized active choices. Hand edits to managed files are backed up and replaced; keep personal variants separately.

## Custom locations

The default library directory follows `${XDG_CONFIG_HOME:-$HOME/.config}`. The active config follows `$STARSHIP_CONFIG`, when set, or that same config directory. You can override both:

```sh
./install.sh --shell zsh \
  --install-dir "$HOME/.local/share/starship-themes" \
  --config-file "$HOME/.config/my-starship.toml"
```

The installer writes the matching `STARSHIP_CONFIG` export and switcher source path into the shell startup file. Reuse these options when updating a custom installation. Paths with spaces are supported.

You can select a theme during installation:

```sh
./install.sh --style A --palette ocean
```

To restore an earlier setup, copy the desired `.backup.*` files over the active config and affected startup files. To disable the integration, remove the `starship-themes` marked blocks from those startup files. Save any backups before deleting the installed directory.

## Repository layout

```text
configs/              Four standalone layout configs, each with all fifteen palettes
activate.sh           Theme selection script
shell-functions.sh    Sourceable starship-theme function
install.sh            Local installer and shell configuration
lib/files.sh          Shared backup and file-writing helpers
tests/test.sh         Isolated Bash integration tests
docs/                 Design notes and an original theme preview
README.md             Installation and usage
AGENTS.md             Guidance for AI agents
```

Edit the canonical files in `configs/`, keeping common modules and palettes consistent across all four layouts. Run the tests with:

```sh
bash tests/test.sh
```

Tests use temporary homes and Git repositories, including actual Starship rendering for all sixty combinations. See [CONTRIBUTING.md](CONTRIBUTING.md) for maintenance guidance. Licensed under [MIT](LICENSE); independent of the Starship project.
