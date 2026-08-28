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
link "nvim"           ".config/nvim"
link "yazi"           ".config/yazi"

if command -v brew >/dev/null 2>&1; then
  echo "Installing Brewfile packages..."
  brew bundle --file="$DOTFILES_DIR/Brewfile"
else
  echo "Homebrew not found; skipping brew bundle. Install it from https://brew.sh first." >&2
fi

echo "Done. Restart your shell (or 'exec zsh') to pick up the new config."
