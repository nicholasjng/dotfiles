#!/usr/bin/env zsh
# jj-prompt — minimal, dependency-free zsh prompt with first-class jj (Jujutsu)
# support and a git fallback. Two-line, Pure-like layout.
#
# Knobs: $JJPROMPT_SYMBOL (default ➜), $JJPROMPT_MAX_EXEC_TIME (seconds, 5).

# --- repo detection ----------------------------------------------------------

jjprompt_in_jj_repo() {
  local d=$PWD
  while [[ -n $d ]]; do
    [[ -d $d/.jj ]] && return 0
    d=${d%/*}
  done
  return 1
}

jjprompt_in_git_repo() {
  local d=$PWD
  while [[ -n $d ]]; do
    [[ -e $d/.git ]] && return 0
    d=${d%/*}
  done
  return 1
}

# Count commits in a revset without a pipe to wc: emit one '.' per commit and
# take the resulting string length. Result in $REPLY.
jjprompt_revcount() {
  local out
  out=$(command jj log --ignore-working-copy --no-graph -r "$1" -T '"."' 2>/dev/null)
  REPLY=${#out}
}

# Format a duration (seconds) as e.g. "1d 3h 2m 5s", dropping leading zeros.
jjprompt_human_time() {
  local -i t=$1 d h m s
  (( d = t / 86400, h = t % 86400 / 3600, m = t % 3600 / 60, s = t % 60 ))
  local out=''
  (( d )) && out+="${d}d "
  (( h )) && out+="${h}h "
  (( m )) && out+="${m}m "
  REPLY="${out}${s}s"
}

# --- VCS segment -------------------------------------------------------------
# jj wins over git, so colocated repos read as jj. --ignore-working-copy keeps
# jj from snapshotting per render. Dynamic text is %-escaped so a '%' in a
# bookmark/description isn't misread as a prompt escape under prompt_subst.

jjprompt_vcs_render() {
  jjprompt_vcs=''

  if jjprompt_in_jj_repo; then
    # Fields, \x1f-separated: change-id, bookmarks on @, state markers, description.
    local out
    out=$(command jj log --ignore-working-copy --no-graph --color=never -r @ -T \
      'change_id.shortest(8) ++ "\x1f" ++ local_bookmarks.join(" ") ++ "\x1f" ++ separate(" ", if(conflict, "✗"), if(divergent, "↯"), if(parents.len() > 1, "⌥"), if(empty, "∅")) ++ "\x1f" ++ coalesce(description.first_line(), "(no description)")' \
      2>/dev/null)
    [[ -z $out ]] && return
    out=${out//\%/%%}
    local cid=${out%%$'\x1f'*}; out=${out#*$'\x1f'}
    local bm=${out%%$'\x1f'*}; out=${out#*$'\x1f'}
    local markers=${out%%$'\x1f'*} desc=${out#*$'\x1f'}

    # Color each marker individually (here, not in the template, since the
    # template output is %-escaped above, which would mangle %F{...} sequences).
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

    # If @ carries no bookmark (anonymous working copy), show the nearest
    # ancestor bookmark as the base.
    if [[ -z $bm ]]; then
      local near
      near=$(command jj log --ignore-working-copy --no-graph -r 'heads(::@ & bookmarks())' -T 'local_bookmarks.join(",")' 2>/dev/null)
      [[ -n $near ]] && bm=${near//\%/%%}
    fi
    [[ -n $bm ]] && bm=" %F{green}${bm}%f"

    # Ahead/behind of trunk(); exclude the empty @ so `jj new trunk` isn't "1 ahead".
    local REPLY arrows=''
    jjprompt_revcount 'trunk()..@ ~ (@ & empty())'
    (( REPLY )) && arrows+="⇡${REPLY}"
    jjprompt_revcount '@..trunk()'
    (( REPLY )) && arrows+="⇣${REPLY}"
    [[ -n $arrows ]] && arrows=" %F{cyan}${arrows}%f"

    jjprompt_vcs=" %F{244}•%f %F{magenta}${cid}%f${bm}${rest}${arrows}"
    return
  fi

  if jjprompt_in_git_repo; then
    local branch
    branch=$(command git symbolic-ref --quiet --short HEAD 2>/dev/null) \
      || branch=$(command git rev-parse --short HEAD 2>/dev/null) \
      || return
    branch=${branch//\%/%%}
    # Dirty marker via porcelain: matches Pure and catches untracked files, at
    # the cost of a full status scan — fine for the git fallback.
    local dirty=''
    [[ -n $(command git status --porcelain --ignore-submodules 2>/dev/null) ]] && dirty='*'
    jjprompt_vcs=" %F{242}${branch}%F{218}${dirty}%f"
  fi
}

# --- hooks -------------------------------------------------------------------

jjprompt_preexec() {
  jjprompt_cmd_start=$EPOCHSECONDS
}

jjprompt_precmd() {
  # Capture exit status FIRST — the jj/git calls below overwrite $?. Color is
  # derived here (not via PROMPT's %(?..)) because PROMPT expands after precmd.
  local -i last_status=$?
  if (( last_status )); then jjprompt_symcolor='%F{red}'; else jjprompt_symcolor='%F{green}'; fi

  # Active Python venv / conda env. Prefer the name set at venv creation.
  jjprompt_venv=''
  if [[ -n $VIRTUAL_ENV ]]; then
    local name=${VIRTUAL_ENV_PROMPT:-${VIRTUAL_ENV:t}}
    jjprompt_venv="%F{242}${name//\%/%%}%f "
  elif [[ -n $CONDA_DEFAULT_ENV ]]; then
    jjprompt_venv="%F{242}${CONDA_DEFAULT_ENV//\%/%%}%f "
  fi

  # Command execution time (only shown past the threshold).
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

# --- setup -------------------------------------------------------------------

jjprompt_setup() {
  setopt prompt_subst
  zmodload -F zsh/datetime +p:EPOCHSECONDS 2>/dev/null
  autoload -Uz add-zsh-hook

  # Step aside from Pure / the old Pure-hack hooks if active, so this can be
  # sourced on top of a running Pure for a side-by-side.
  local fn
  for fn in prompt_pure_precmd prompt_jj_info; do
    (( $+functions[$fn] )) && add-zsh-hook -d precmd $fn
  done
  (( $+functions[prompt_pure_preexec] )) && add-zsh-hook -d preexec prompt_pure_preexec
  RPROMPT=''

  # We render env names ourselves; silence the tools' built-in prefixes.
  export VIRTUAL_ENV_DISABLE_PROMPT=1
  export CONDA_CHANGEPS1=no

  typeset -g jjprompt_newline=$'\n%{\r%}'   # %{\r%} resets the column for clean redraws
  typeset -g jjprompt_cmd_start=0 jjprompt_vcs='' jjprompt_exectime=''
  typeset -g jjprompt_venv='' jjprompt_symcolor='%F{green}'
  typeset -g jjprompt_host=''
  [[ -n $SSH_CONNECTION ]] && jjprompt_host='%F{242}%n@%m%f '

  add-zsh-hook precmd  jjprompt_precmd
  add-zsh-hook preexec jjprompt_preexec
  # Run our precmd FIRST so it captures $? before any other precmd hook can.
  precmd_functions=(jjprompt_precmd ${precmd_functions:#jjprompt_precmd})

  # Leading newline = Pure-style spacing; symbol color is exit-status driven.
  PROMPT='${jjprompt_newline}${jjprompt_host}%F{blue}%~%f${jjprompt_vcs}${jjprompt_exectime}${jjprompt_newline}${jjprompt_venv}${jjprompt_symcolor}${JJPROMPT_SYMBOL:-➜}%f '
  PROMPT2='%F{242}… %f'
}

jjprompt_setup
