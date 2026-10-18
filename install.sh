#!/usr/bin/env bash
# Symlinks this repo's configs into place and installs Brewfile packages.
# Safe to re-run: existing real files/dirs are backed up once with a
# .bak-<timestamp> suffix before the symlink is created; existing correct
# symlinks are left alone.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_SUFFIX="bak-$(date +%Y%m%d%H%M%S)"

link() {
  local src="$DOTFILES_DIR/$1" dest="$HOME/$2"
  mkdir -p "$(dirname "$dest")"
  if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
    return 0
  fi
  if [[ -e "$dest" || -L "$dest" ]]; then
    echo "Backing up existing $dest -> $dest.$BACKUP_SUFFIX"
    mv "$dest" "$dest.$BACKUP_SUFFIX"
  fi
  ln -s "$src" "$dest"
  echo "Linked $dest -> $src"
}

link "zsh/.zshrc"    ".zshrc"
link "zsh/.zprofile" ".zprofile"
link "starship/starship.toml" ".config/starship.toml"
link "nvim"           ".config/nvim"
link "yazi"           ".config/yazi"
link "tmux/tmux.conf"      ".config/tmux/tmux.conf"
link "lazygit/config.yml" "Library/Application Support/lazygit/config.yml"
link "claude/statusline.sh" ".claude/statusline.sh"
link "claude/settings.json" ".claude/settings.json"
link "vimrc/.vimrc"         ".vimrc"
link "karabiner"            ".config/karabiner"
link "ideavimrc"            ".config/ideavim"
link "ideavimrc/.ideavimrc" ".ideavimrc"

if command -v brew >/dev/null 2>&1; then
  echo "Installing Brewfile packages..."
  brew bundle --file="$DOTFILES_DIR/Brewfile"
else
  echo "Homebrew not found; skipping brew bundle. Install it from https://brew.sh first." >&2
fi

if command -v npm >/dev/null 2>&1; then
  echo "Installing global npm packages..."
  npm install --global --ignore-scripts @earendil-works/pi-coding-agent @fission-ai/openspec vercel
else
  echo "npm not found; skipping global npm packages (Homebrew installs node above)." >&2
fi

if command -v ya >/dev/null 2>&1; then
  echo "Installing yazi packages (flavors/plugins from yazi/package.toml)..."
  (cd "$DOTFILES_DIR/yazi" && ya pkg install)
fi

echo "Done. Restart your shell (or 'exec zsh') to pick up the new config."
