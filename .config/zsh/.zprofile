if [[ -z "$EDITOR" ]]; then
  export EDITOR='hx'
fi
if [[ -z "$VISUAL" ]]; then
  export VISUAL='hx'
fi
if [[ -z "$PAGER" ]]; then
  export PAGER='less'
fi

if [[ -z "$LANG" ]]; then
  export LANG='en_US.UTF-8'
fi

export LC_ALL=en_US.UTF-8

typeset -gU cdpath fpath mailpath path

path=(
  $HOME/{,s}bin(N)
  $HOME/.local/bin
  $HOME/.cargo/bin
  /opt/{homebrew,local}/{,s}bin(N)
  /usr/local/{,s}bin(N)
  $path
)

# -X disables screen clearing and mouse-wheel scrolling.
if [[ -z "$LESS" ]]; then
  export LESS='-g -i -M -R -S -w -X -z-4'
fi

if [[ -z "$LESSOPEN" ]] && (( $#commands[(i)lesspipe(|.sh)] )); then
  export LESSOPEN="| /usr/bin/env $commands[(i)lesspipe(|.sh)] %s 2>&-"
fi

if (( $+commands[brew] )); then
  eval "$(brew shellenv)"
fi

# Drop stale PATH entries injected by macOS path_helper.
function prune_path() {
  local -a kept
  local dir
  for dir in $path; do
    [[ -d $dir ]] && kept+=$dir
  done
  path=($kept)
}
prune_path
