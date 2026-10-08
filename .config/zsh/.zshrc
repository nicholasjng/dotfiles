ZPLUGIN_DIR="${ZDOTDIR}/plugins"
typeset -gU fpath

# Options
unsetopt BEEP
setopt AUTO_CD GLOB_DOTS NOMATCH MENU_COMPLETE EXTENDED_GLOB INTERACTIVE_COMMENTS APPEND_HISTORY

# History
HISTFILE="$ZDOTDIR/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt BANG_HIST EXTENDED_HISTORY HIST_EXPIRE_DUPS_FIRST HIST_IGNORE_DUPS HIST_IGNORE_ALL_DUPS \
       HIST_FIND_NO_DUPS HIST_IGNORE_SPACE HIST_SAVE_NO_DUPS HIST_REDUCE_BLANKS HIST_VERIFY

# Completion
zstyle ':completion:*' menu yes select
zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
zmodload zsh/complist
_comp_options+=(globdots)
zle_highlight=('paste:none')

if (( $+commands[brew] )); then
    BREW_PREFIX="${HOMEBREW_PREFIX:-$(brew --prefix)}"
    fpath+=("$BREW_PREFIX/share/zsh/site-functions")
fi
autoload -Uz compinit
compinit -d "$ZDOTDIR/.zcompdump"

# Plugins
function _plug() {
    local plugin_name="${1##*/}" plugin_dir="$ZPLUGIN_DIR/${1##*/}" f
    for f in "$plugin_dir/$plugin_name.plugin.zsh" "$plugin_dir/$plugin_name.zsh" "$plugin_dir/init.zsh"; do
        [[ -f "$f" ]] && { source "$f"; return; }
    done
}

_plug "zsh-autosuggestions"

_plug "jj-prompt"

# Key bindings
autoload -Uz colors && colors
autoload -U up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey "^[[A" up-line-or-beginning-search
bindkey "^[[B" down-line-or-beginning-search
bindkey "^[[H" beginning-of-line
bindkey "^[[F" end-of-line
bindkey "^H"   backward-kill-word
bindkey -M menuselect '?' history-incremental-search-forward
bindkey -M menuselect '/' history-incremental-search-backward
bindkey -s "^x" "^usource $ZDOTDIR/.zshrc\n"

case "$(uname -s)" in
    Darwin) alias ls='ls -G' ;;
    Linux)  alias ls='ls --color=auto' ;;
esac

# Tools
(( $+commands[fzf] )) && eval "$(fzf --zsh)"
(( $+commands[zoxide] )) && eval "$(zoxide init zsh)"
command -v picky >/dev/null && eval "$(picky completions zsh)"

function zsh_update_plugins() {
    local repo_dir="${ZPLUGIN_DIR:A:h:h:h}"
    print -P '%B%F{blue}==>%f%b %BUpdating plugins...%b'
    git -C "$repo_dir" submodule update --init --remote --recursive -- \
        .config/zsh/plugins/zsh-autosuggestions \
        .config/zsh/plugins/zsh-syntax-highlighting || return
    print -P '  %F{green}✓%f Done.'
}

# Must load after widget definitions and bindings.
_plug "zsh-syntax-highlighting"
