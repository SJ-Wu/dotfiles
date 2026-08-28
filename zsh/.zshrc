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
# Shadow the `yazi` command itself so quitting with `q` `cd`s the shell into
# the last visited directory (yazi writes it to --cwd-file). Quitting with
# `Q` still leaves the shell where it started — that's yazi's own default
# distinction. `command yazi` inside bypasses this function to call the
# real binary, avoiding infinite recursion.
function yazi() {
  local tmp cwd
  tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
  command yazi "$@" --cwd-file="$tmp"
  if cwd="$(command cat -- "$tmp")" && [[ -n "$cwd" && "$cwd" != "$PWD" ]]; then
    builtin cd -- "$cwd"
  fi
  rm -f -- "$tmp"
}
alias y=yazi

# THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
