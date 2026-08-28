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

# THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
