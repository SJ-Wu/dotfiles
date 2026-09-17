# .zprofile — sourced once for login shells, before .zshrc.
# Keep this to PATH/env setup that only needs to run once per login.

# Homebrew (Apple Silicon default prefix). Safe no-op if already on PATH.
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Added by Toolbox App
export PATH="$PATH:/Users/nick/Library/Application Support/JetBrains/Toolbox/scripts"

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init.zsh 2>/dev/null || :
