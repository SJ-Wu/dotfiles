# .zshrc — sourced for every interactive shell.

export PATH="$HOME/.local/bin:$PATH"

# --- fzf ---------------------------------------------------------------
[[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh
if command -v fzf >/dev/null 2>&1; then
  source <(fzf --zsh)
fi

# --- zoxide (smarter cd) ------------------------------------------------
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

# --- yazi -----------------------------------------------------------------
# Wrap yazi so quitting it can `cd` the shell into the last visited directory.
function y() {
  local tmp cwd
  tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
  yazi "$@" --cwd-file="$tmp"
  if cwd="$(command cat -- "$tmp")" && [[ -n "$cwd" && "$cwd" != "$PWD" ]]; then
    builtin cd -- "$cwd"
  fi
  rm -f -- "$tmp"
}

# THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
