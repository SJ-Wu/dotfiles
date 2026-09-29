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

# --- starship (prompt) ----------------------------------------------------
# 設定檔在本 repo 的 starship/starship.toml，由 install.sh 連到
# ~/.config/starship.toml（starship 的預設位置）。
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

# --- 進出專案目錄自動切換 venv (python) -----------------------------------
# 從 $PWD 一路往上找 .venv：
#   - 新分頁直接開在專案（或子目錄）裡也會啟用
#   - z/cd 直接跳進子目錄找得到上層的 .venv
#   - 換到別的專案自動切成該專案的 venv；離開專案樹才 deactivate
# starship 的 [python] 模組讀 $VIRTUAL_ENV，提示字元會跟著這裡一起切。
autoload -Uz add-zsh-hook

# activate 腳本預設會自己在 PS1 前面加 "(.venv) "；starship 已經顯示 venv 了，
# 關掉避免重複（對不吃 starship 的 shell 也乾淨）。
export VIRTUAL_ENV_DISABLE_PROMPT=1

# deactivate 是 activate 腳本定義的 shell function，只在「這個 shell 自己啟用過」
# 時才存在。VIRTUAL_ENV 若是繼承來的（tmux 從已啟用的 shell 開新窗、IDE 的
# integrated terminal、`env VIRTUAL_ENV=... zsh`），那個 function 根本不存在，
# 沒有 fallback 的話變數會一路卡著，prompt 上的 venv 就永遠是假的。
_deactivate_venv() {
  if (( $+functions[deactivate] )); then
    deactivate
  else
    [[ -n $VIRTUAL_ENV ]] && path=( ${path:#$VIRTUAL_ENV/bin} )
    unset VIRTUAL_ENV VIRTUAL_ENV_PROMPT
  fi
  return 0
}

# 每個分支都明確 return 0：這個 function 會在 .zshrc 尾端跑一次，若讓它帶著
# 失敗的 [[ ]] 狀態離開，第一個提示字元的 ❯ 會被 starship 畫成紅色（假的錯誤）。
_auto_venv() {
  local dir=$PWD
  while [[ $dir != / ]]; do
    if [[ -f $dir/.venv/bin/activate ]]; then
      if [[ $VIRTUAL_ENV != $dir/.venv ]]; then
        _deactivate_venv
        source "$dir/.venv/bin/activate"
      fi
      return 0
    fi
    dir=${dir:h}
  done
  [[ -n $VIRTUAL_ENV ]] && _deactivate_venv
  return 0
}
add-zsh-hook chpwd _auto_venv   # 只在目錄切換時跑(chpwd)，掛 precmd 每個提示字元都跑是浪費
_auto_venv                      # 啟動時先跑一次

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

# >>> grok installer >>>
export PATH="$HOME/.grok/bin:$PATH"
fpath=(~/.grok/completions/zsh $fpath)
autoload -Uz compinit && compinit -C
# <<< grok installer <<<

# THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
