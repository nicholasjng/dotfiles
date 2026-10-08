#!/usr/bin/env zsh
# Two-line jj prompt with a Git fallback. Options are documented in README.md.

# Repo detection

# Nearest repo type in $REPLY; jj wins for colocated repos.
jjprompt_repo_type() {
  local d=$PWD
  REPLY=''
  while true; do
    if [[ -d $d/.jj ]] && (( $+commands[jj] )); then
      REPLY=jj
      return
    fi
    if [[ -e $d/.git ]] && (( $+commands[git] )); then
      REPLY=git
      return
    fi
    [[ $d == / ]] && break
    d=${d:h}
  done
}

# Commit count in $REPLY.
jjprompt_revcount() {
  local out
  out=$(command jj log --ignore-working-copy --no-graph --color=never -r "$1" -T '"."' 2>/dev/null)
  REPLY=${#out}
}

# Formatted duration in $REPLY.
jjprompt_human_time() {
  local -i t=$1 d h m s
  (( d = t / 86400, h = t % 86400 / 3600, m = t % 3600 / 60, s = t % 60 ))
  local out=''
  (( d )) && out+="${d}d "
  (( h )) && out+="${h}h "
  (( m )) && out+="${m}m "
  REPLY="${out}${s}s"
}

# VCS
# --ignore-working-copy avoids snapshots during prompt rendering.

jjprompt_vcs_render() {
  jjprompt_vcs=''
  local REPLY
  jjprompt_repo_type

  if [[ $REPLY == jj ]]; then
    local description_width=${JJPROMPT_MAX_DESCRIPTION_LENGTH:-50}
    [[ $description_width == <1-> ]] || description_width=50
    if (( COLUMNS > 0 && description_width > COLUMNS / 2 )); then
      description_width=$(( COLUMNS / 2 > 0 ? COLUMNS / 2 : 1 ))
    fi
    # Unit-separated fields: change ID, bookmarks, markers, description.
    local out
    out=$(command jj log --ignore-working-copy --no-graph --color=never -r @ -T \
      'change_id.shortest(8) ++ "\x1f" ++ local_bookmarks.join(" ") ++ "\x1f" ++ separate(" ", if(conflict, "✗"), if(divergent, "↯"), if(parents.len() > 1, "⌥"), if(empty, "∅")) ++ "\x1f" ++ truncate_end('"$description_width"', coalesce(description.first_line(), "(no description)"), "…")' \
      2>/dev/null) || return
    [[ -z $out ]] && return
    # Escape literal '%' for prompt expansion.
    out=${out//\%/%%}
    local cid=${out%%$'\x1f'*}; out=${out#*$'\x1f'}
    local bm=${out%%$'\x1f'*}; out=${out#*$'\x1f'}
    local markers=${out%%$'\x1f'*} desc=${out#*$'\x1f'}

    # Add colors after escaping repository text.
    local rest='' m
    for m in ${(s: :)markers}; do
      case $m in
        ✗) rest+=" %F{red}${m}%f" ;;
        ↯) rest+=" %F{yellow}${m}%f" ;;
        ⌥) rest+=" %F{cyan}${m}%f" ;;
        ∅) rest+=" %F{244}${m}%f" ;;
      esac
    done
    rest+=" %F{244}${desc}%f"

    # Fall back to the nearest ancestor bookmarks.
    if [[ -z $bm ]]; then
      local near
      near=$(command jj log --ignore-working-copy --no-graph --color=never -r 'heads(::@ & bookmarks())' -T 'local_bookmarks.join(",") ++ " "' 2>/dev/null)
      near=${near% }
      [[ -n $near ]] && bm=${near//\%/%%}
    fi
    [[ -n $bm ]] && bm=" %F{green}${bm}%f"

    # Don't count an empty working copy as ahead of trunk.
    local arrows=''
    jjprompt_revcount 'trunk()..@ ~ (@ & empty())'
    (( REPLY )) && arrows+="⇡${REPLY}"
    jjprompt_revcount '@..trunk()'
    (( REPLY )) && arrows+="⇣${REPLY}"
    [[ -n $arrows ]] && arrows=" %F{cyan}${arrows}%f"

    jjprompt_vcs=" %F{244}•%f %F{magenta}${cid}%f${bm}${rest}${arrows}"
    return
  fi

  if [[ $REPLY == git ]]; then
    local branch
    branch=$(command git symbolic-ref --quiet --short HEAD 2>/dev/null) \
      || branch=$(command git rev-parse --short HEAD 2>/dev/null) \
      || return
    branch=${branch//\%/%%}
    local dirty=''
    [[ -n $(command git status --porcelain --ignore-submodules 2>/dev/null) ]] && dirty='*'
    jjprompt_vcs=" %F{242}${branch}%F{218}${dirty}%f"
  fi
}

# Hooks

jjprompt_preexec() {
  jjprompt_cmd_start=$EPOCHSECONDS
}

jjprompt_precmd() {
  # Capture $? before VCS commands overwrite it.
  local -i last_status=$?
  if (( last_status )); then jjprompt_symcolor='%F{red}'; else jjprompt_symcolor='%F{green}'; fi

  jjprompt_venv=''
  if [[ -n $VIRTUAL_ENV ]]; then
    local name=${VIRTUAL_ENV_PROMPT:-${VIRTUAL_ENV:t}}
    jjprompt_venv="%F{242}${name//\%/%%}%f "
  elif [[ -n $CONDA_DEFAULT_ENV ]]; then
    jjprompt_venv="%F{242}${CONDA_DEFAULT_ENV//\%/%%}%f "
  fi

  jjprompt_exectime=''
  if (( jjprompt_cmd_start )); then
    local -i elapsed=$(( EPOCHSECONDS - jjprompt_cmd_start ))
    if (( elapsed >= ${JJPROMPT_MAX_EXEC_TIME:-5} )); then
      local REPLY; jjprompt_human_time $elapsed
      jjprompt_exectime=" %F{yellow}${REPLY}%f"
    fi
    jjprompt_cmd_start=0
  fi

  jjprompt_vcs_render
}

# Setup

jjprompt_setup() {
  setopt prompt_subst
  zmodload -F zsh/datetime +p:EPOCHSECONDS 2>/dev/null
  autoload -Uz add-zsh-hook

  # Remove legacy Pure hooks.
  local fn
  for fn in prompt_pure_precmd prompt_jj_info; do
    (( $+functions[$fn] )) && add-zsh-hook -d precmd $fn
  done
  (( $+functions[prompt_pure_preexec] )) && add-zsh-hook -d preexec prompt_pure_preexec
  RPROMPT=''

  # Avoid duplicate environment prefixes.
  export VIRTUAL_ENV_DISABLE_PROMPT=1
  export CONDA_CHANGEPS1=no

  typeset -g jjprompt_newline=$'\n%{\r%}'   # Reset the column for redraws.
  typeset -g jjprompt_cmd_start=0 jjprompt_vcs='' jjprompt_exectime=''
  typeset -g jjprompt_venv='' jjprompt_symcolor='%F{green}'
  typeset -g jjprompt_host=''
  [[ -n $SSH_CONNECTION ]] && jjprompt_host='%F{242}%n@%m%f '

  add-zsh-hook precmd  jjprompt_precmd
  add-zsh-hook preexec jjprompt_preexec
  # Capture the command's status before other hooks.
  precmd_functions=(jjprompt_precmd ${precmd_functions:#jjprompt_precmd})

  PROMPT='${jjprompt_newline}${jjprompt_host}%F{blue}%~%f${jjprompt_vcs}${jjprompt_exectime}${jjprompt_newline}${jjprompt_venv}${jjprompt_symcolor}${JJPROMPT_SYMBOL:-➜}%f '
  PROMPT2='%F{242}… %f'
}

jjprompt_setup
