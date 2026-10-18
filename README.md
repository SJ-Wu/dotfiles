# dotfiles

Nick's personal dev environment: Homebrew packages, zsh, [yazi](https://yazi-rs.github.io/), [Neovim](https://neovim.io/), [lazygit](https://github.com/jesseduffield/lazygit), and
[IdeaVim](https://plugins.jetbrains.com/plugin/164-ideavim) config.

## Layout

```
Brewfile      # `brew bundle` package list (CLI tools + casks)
zsh/          -> ~/.zshrc, ~/.zprofile
nvim/         -> ~/.config/nvim
yazi/         -> ~/.config/yazi
lazygit/      -> ~/Library/Application Support/lazygit/config.yml
vimrc/        -> ~/.vimrc (system vim; no plugins)
karabiner/    -> ~/.config/karabiner (Karabiner-Elements)
ideavimrc/    -> ~/.ideavimrc + ~/.config/ideavim (IdeaVim for IntelliJ/PyCharm/WebStorm)
install.sh    # symlinks everything above + runs `brew bundle` + `ya pkg install`
```

`yazi/flavors/` and `yazi/plugins/` are not committed — they're fetched by
`ya pkg install` from the lockfile `yazi/package.toml` (managed with
`ya pkg add <owner>/<repo>[:<pkg>]` / `ya pkg upgrade`).

## Setup

On a new Mac with [Claude Code](https://code.claude.com/docs/en/setup) installed, one prompt does the whole thing — it follows the "Restoring this environment on a new Mac" steps in `AGENTS.md` (Homebrew, clone, `install.sh`, verify):

```sh
claude "Restore my dev environment from https://github.com/SJ-Wu/dotfiles"
```

Or by hand:

```sh
git clone https://github.com/SJ-Wu/dotfiles.git ~/Github/dotfiles
cd ~/Github/dotfiles
./install.sh
```

`install.sh` is idempotent: it backs up any existing real file/directory once
(`<name>.bak-<timestamp>`) before symlinking, and leaves already-correct
symlinks alone.

## Updating the Brewfile

After installing/removing packages with `brew`, regenerate it:

```sh
brew bundle dump --force --describe --file=Brewfile
```
