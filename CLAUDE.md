# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Personal dotfiles: Homebrew packages, zsh, [yazi](https://yazi-rs.github.io/) (terminal file manager), Neovim, [lazygit](https://github.com/jesseduffield/lazygit) config, IdeaVim config for JetBrains IDEs, and Claude Code settings. Files under `zsh/`, `nvim/`, `yazi/`, `lazygit/`, `ideavimrc/`, and `claude/` are symlinked into `$HOME` (or, for lazygit, `~/Library/Application Support`; for `claude/`, `~/.claude`) — they are not copied — so an edit here takes effect on next shell/app restart, no install step required for iterating.

## Commands

```sh
./install.sh                                          # (re)create all symlinks + `brew bundle` + `ya pkg install`
brew bundle dump --force --describe --file=Brewfile    # regenerate Brewfile from currently installed packages
cd yazi && ya pkg add <owner>/<repo>[:<pkg>]            # add a yazi flavor/plugin (writes package.toml)
cd yazi && ya pkg upgrade                               # upgrade all yazi flavors/plugins in package.toml
```

There is no build, lint, or test step — this is plain config, not a program.

To check a change without touching the real system, symlink into a scratch `$HOME` instead of running `install.sh` directly:

```sh
HOME=/tmp/dotfiles-test ./install.sh
```

## Architecture

- **`install.sh`** is the only thing that ties the repo to the live system. It's a single idempotent symlink step (`link()`  function) mapping repo path -> `$HOME` path, followed by `brew bundle`. Any new dotfile must be added there explicitly — nothing is auto-discovered. It backs up a pre-existing real file/dir once as `<name>.bak-<timestamp>` before linking; an already-correct symlink is left alone.
- **`Brewfile`** is the single source of truth for installed CLI tools/casks. Keep it in sync with the real system via `brew bundle dump`, don't hand-edit it out of sync with what's actually installed.
- **`nvim/`** follows the standard lazy.nvim layout: `init.lua` only requires three modules in order — `config.options`, `config.keymaps`, then `config.lazy` (which bootstraps lazy.nvim itself and calls `require("lazy").setup("plugins")`). Every file under `nvim/lua/plugins/` is auto-loaded as a lazy.nvim plugin spec — add a plugin by dropping a new file there, nothing to register elsewhere. Keep `init.lua` thin; real settings belong in `lua/config/*` or a plugin spec.
- **`yazi/`** config files (`yazi.toml`, `keymap.toml`, `theme.toml`, `init.lua`) are merged on top of yazi's built-in defaults, not a full replacement — only put overrides here, not the complete default set. Flavors/plugins are managed by yazi's own package manager (`ya pkg`): `yazi/package.toml` is the lockfile (committed), but `yazi/flavors/` and `yazi/plugins/` themselves are fetched by `ya pkg install`/`install.sh` and gitignored — never hand-edit or commit into those two directories, and don't forget a plugin usually needs wiring in *two* places: `init.lua` (`require("<plugin>"):setup{...}`) and/or `keymap.toml` (bind a key to `plugin <name>`).
- **`zsh/.zprofile`** vs **`zsh/.zshrc`**: `.zprofile` runs once per login shell (PATH/env setup only, e.g. Homebrew shellenv); `.zshrc` runs for every interactive shell (tool init like `fzf`/`zoxide`, functions, aliases). The SDKMAN block at the end of `.zshrc` must stay the last thing in the file — SDKMAN's own installer enforces this.
- **`ideavimrc/`** is the IdeaVim config for JetBrains IDEs. Two symlinks: `ideavimrc/.ideavimrc` -> `~/.ideavimrc` (the entry point IdeaVim reads) and the whole directory -> `~/.config/ideavim` (so the entry file can `source` its siblings by a stable path). `.ideavimrc` holds everything shared and ends with an `if &ide =~? ...` block that auto-sources `py_ideavimrc` under PyCharm or `java_ideavimrc` under IntelliJ IDEA; `zij`/`zpc` source them manually. Language-specific files must stay free of duplicated common mappings. Verify action names with `:actionlist <keyword>` inside the IDE before adding an `:action` mapping - a wrong name fails silently.
- **`claude/`** holds Claude Code's global config: `settings.json` (symlinked whole, so it's the single source of truth for `~/.claude/settings.json` — don't hand-edit the live file out of sync) and `statusline.sh`, the script `settings.json`'s `statusLine.command` points at. The script reads a JSON payload on stdin (see `code.claude.com/docs/en/statusline` for the schema) and prints the (ANSI-colored, multi-line) status line to stdout; it must stay executable (`chmod +x`) since `settings.json` invokes it by path, not via `bash`.
