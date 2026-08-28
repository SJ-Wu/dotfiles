# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Personal dotfiles: Homebrew packages, zsh, [yazi](https://yazi-rs.github.io/) (terminal file manager), and Neovim config. Files under `zsh/`, `nvim/`, and `yazi/` are symlinked into `$HOME` — they are not copied — so an edit here takes effect on next shell/app restart, no install step required for iterating.

## Commands

```sh
./install.sh                                          # (re)create all symlinks + `brew bundle` install
brew bundle dump --force --describe --file=Brewfile    # regenerate Brewfile from currently installed packages
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
- **`yazi/`** config files (`yazi.toml`, `keymap.toml`, `theme.toml`) are merged on top of yazi's built-in defaults, not a full replacement — only put overrides here, not the complete default set.
- **`zsh/.zprofile`** vs **`zsh/.zshrc`**: `.zprofile` runs once per login shell (PATH/env setup only, e.g. Homebrew shellenv); `.zshrc` runs for every interactive shell (tool init like `fzf`/`zoxide`, functions, aliases). The SDKMAN block at the end of `.zshrc` must stay the last thing in the file — SDKMAN's own installer enforces this.
