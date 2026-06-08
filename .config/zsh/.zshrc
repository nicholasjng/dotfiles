ZPLUGIN_DIR="${ZDOTDIR}/plugins"
BREW_PREFIX="$(brew --prefix)"

# --- Options ---
unsetopt BEEP
setopt AUTO_CD GLOB_DOTS NOMATCH MENU_COMPLETE EXTENDED_GLOB INTERACTIVE_COMMENTS APPEND_HISTORY

# --- History ---
HISTFILE="$ZDOTDIR/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt BANG_HIST EXTENDED_HISTORY HIST_EXPIRE_DUPS_FIRST HIST_IGNORE_DUPS HIST_IGNORE_ALL_DUPS \
       HIST_FIND_NO_DUPS HIST_IGNORE_SPACE HIST_SAVE_NO_DUPS HIST_REDUCE_BLANKS HIST_VERIFY

# --- Completion ---
zstyle ':completion:*' menu yes select
zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
zmodload zsh/complist
_comp_options+=(globdots)
zle_highlight=('paste:none')

fpath+=("$BREW_PREFIX/share/zsh/site-functions")
autoload -Uz compinit
for dump in "$ZDOTDIR/.zcompdump"(N.mh+24); do
    compinit
done
compinit -C

# --- Plugins ---
function _plug() {
    local plugin_name="${1##*/}" plugin_dir="$ZPLUGIN_DIR/${1##*/}" f
    for f in "$plugin_dir/$plugin_name.plugin.zsh" "$plugin_dir/$plugin_name.zsh" "$plugin_dir/init.zsh"; do
        [[ -f "$f" ]] && { source "$f"; return; }
    done
}

_plug "zsh-autosuggestions"
_plug "zsh-syntax-highlighting"

# --- Prompt ---
# jj-prompt: a dependency-free, jj-first two-line prompt with a git fallback.
# Self-contained in plugins/jj-prompt (symbol + success/error colors included).
_plug "jj-prompt"

# --- Key bindings ---
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

# --- Tools ---
eval "$(fzf --zsh)"
eval "$(zoxide init zsh)"

function zsh_update_plugins() {
    local d
    print -P '%B%F{blue}==>%f%b %BUpdating plugins...%b'
    for d in "$ZPLUGIN_DIR"/*/; do
        [[ -e "$d/.git" ]] || continue
        print -P "  %F{yellow}·%f ${d:t}"
        git -C "$d" pull --ff-only
    done
    print -P '  %F{green}✓%f Done.'
}
