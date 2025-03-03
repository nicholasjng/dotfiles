# zmodload zsh/zprof
# Created by Zap installer
[ -f "${XDG_DATA_HOME:-$HOME/.local/share}/zap/zap.zsh" ] && source "${XDG_DATA_HOME:-$HOME/.local/share}/zap/zap.zsh"

fpath+=("$ZAP_DIR/plugins/pure" "$(brew --prefix)/share/zsh/site-functions")

plug "zsh-users/zsh-autosuggestions"
plug "sindresorhus/pure"
plug "zap-zsh/supercharge"
plug "zsh-users/zsh-syntax-highlighting"

source "$(brew --prefix)/share/google-cloud-sdk/path.zsh.inc"
source "$(brew --prefix)/share/google-cloud-sdk/completion.zsh.inc"

# Load and initialise completion system
autoload -Uz compinit
compinit

eval "$(fzf --zsh)"
eval "$(zoxide init zsh)"

export PURE_PROMPT_SYMBOL="➜"
zstyle ':prompt:pure:prompt:success' color green
zstyle ':prompt:pure:prompt:error' color red

bindkey "^[[H" beginning-of-line
bindkey "^[[F" end-of-line
# zprof

