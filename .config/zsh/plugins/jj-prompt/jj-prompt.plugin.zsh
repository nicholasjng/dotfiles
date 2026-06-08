#!/usr/bin/env zsh
# jj-prompt — a minimal, dependency-free zsh prompt with first-class jj
# (Jujutsu) support and a lightweight git fallback. Two-line, Pure-like layout:
#
#     ~/path  jj <change-id> <bookmarks/markers> <desc> ⇡N⇣N   3s
#     ➜
#
# TRY IT (without touching your config): in a scratch shell, run
#     source ~/.config/zsh/plugins/jj-prompt/jj-prompt.plugin.zsh
# Sourcing activates it and steps aside from Pure for that shell only; open a
# new shell to get Pure back. To ADOPT it, replace the `prompt pure` block (and
# the jj-on-Pure hack) in .zshrc with `_plug "jj-prompt"`.
#
# Knobs: $JJPROMPT_SYMBOL (default ➜), $JJPROMPT_MAX_EXEC_TIME (seconds, 5).

# --- repo detection (process-free: just walk up looking for the marker dir) --

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

# Format a duration (seconds) as e.g. "1d 3h 2m 5s", dropping leading zeros.
# Result is returned in $REPLY (zsh convention) to avoid a subshell.
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
# Sets $jjprompt_vcs. jj wins over git, so colocated repos read as jj.
# --ignore-working-copy keeps jj from snapshotting / creating an op per render.
# Dynamic text is %-escaped so a bookmark/branch/description containing '%'
# can't be misread as a prompt escape once prompt_subst expands the segment.

jjprompt_vcs_render() {
  jjprompt_vcs=''

  if jjprompt_in_jj_repo; then
    # Fields, \x1f-separated: change-id, local bookmarks on @, then markers+desc.
    # Bookmarks are split out so we can detect when @ is anonymous (the usual
    # case) and fall back to the nearest ancestor bookmark below.
    local out
    out=$(command jj log --ignore-working-copy --no-graph --color=never -r @ -T \
      'change_id.shortest(8) ++ "\x1f" ++ local_bookmarks.join(" ") ++ "\x1f" ++ separate(" ", if(conflict, "conflict"), if(divergent, "divergent"), if(empty, "(empty)"), coalesce(description.first_line(), "(no description)"))' \
      2>/dev/null)
    [[ -z $out ]] && return
    out=${out//\%/%%}
    local cid=${out%%$'\x1f'*} tmp=${out#*$'\x1f'}
    local bm=${tmp%%$'\x1f'*} rest=${tmp#*$'\x1f'}

    # If @ carries no bookmark (anonymous working copy), show the nearest
    # ancestor bookmark with its distance, e.g. "main+2". Costs two extra jj
    # calls, but only in this (common) fallback path.
    if [[ -z $bm ]]; then
      local near
      near=$(command jj log --ignore-working-copy --no-graph -r 'heads(::@ & bookmarks())' -T 'local_bookmarks.join(",")' 2>/dev/null)
      if [[ -n $near ]]; then
        local d
        d=$(command jj log --ignore-working-copy --no-graph -r 'heads(::@ & bookmarks())..@' -T '"."' 2>/dev/null)
        bm="${near//\%/%%}+${#d}"
      fi
    fi
    [[ -n $bm ]] && bm=" %F{green}${bm}%f"

    # Ahead/behind of trunk(); the empty working-copy commit is excluded so a
    # fresh `jj new trunk` doesn't read as "1 ahead". Silent if trunk() is N/A.
    local ahead behind arrows=''
    ahead=$(command jj log --ignore-working-copy --no-graph -r 'trunk()..@ ~ (@ & empty())' -T '"."' 2>/dev/null)
    behind=$(command jj log --ignore-working-copy --no-graph -r '@..trunk()' -T '"."' 2>/dev/null)
    (( ${#ahead} ))  && arrows+="⇡${#ahead}"
    (( ${#behind} )) && arrows+="⇣${#behind}"
    [[ -n $arrows ]] && arrows=" %F{cyan}${arrows}%f"

    jjprompt_vcs=" %F{244}•%f %F{magenta}${cid}%f${bm} %F{244}${rest}%f${arrows}"
    return
  fi

  if jjprompt_in_git_repo; then
    local branch
    branch=$(command git symbolic-ref --quiet --short HEAD 2>/dev/null) \
      || branch=$(command git rev-parse --short HEAD 2>/dev/null) \
      || return
    branch=${branch//\%/%%}
    # Dirty marker. Uses porcelain (one process) so it matches Pure and catches
    # untracked files too, at the cost of a full status scan in large repos —
    # acceptable for the git fallback in a jj-first setup.
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
  # Capture the command's exit status FIRST — before the arithmetic and jj/git
  # calls below, which all overwrite $?. The symbol color is derived here into a
  # variable rather than via PROMPT's %(?..), because PROMPT is expanded only
  # after precmd has run those commands, by which point $? no longer reflects
  # your command. (We also run first among precmd hooks — see jjprompt_setup.)
  local -i last_status=$?
  if (( last_status )); then jjprompt_symcolor='%F{red}'; else jjprompt_symcolor='%F{green}'; fi

  # Active Python venv / conda env, rendered just before the prompt symbol.
  # Prefer $VIRTUAL_ENV_PROMPT (the name set at venv creation) over the dir name.
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

  # Step aside from Pure and the old Pure-hack hooks if they're active in this
  # shell, so this can be sourced on top of a running Pure for a side-by-side.
  local fn
  for fn in prompt_pure_precmd prompt_jj_info; do
    (( $+functions[$fn] )) && add-zsh-hook -d precmd $fn
  done
  (( $+functions[prompt_pure_preexec] )) && add-zsh-hook -d preexec prompt_pure_preexec
  RPROMPT=''

  # We render the env name ourselves, so silence the tools' built-in prefixes.
  export VIRTUAL_ENV_DISABLE_PROMPT=1
  export CONDA_CHANGEPS1=no

  typeset -g jjprompt_newline=$'\n%{\r%}'   # %{\r%} resets the column for clean redraws
  typeset -g jjprompt_cmd_start=0 jjprompt_vcs='' jjprompt_exectime=''
  typeset -g jjprompt_venv='' jjprompt_symcolor='%F{green}'
  typeset -g jjprompt_host=''
  [[ -n $SSH_CONNECTION ]] && jjprompt_host='%F{242}%n@%m%f '

  add-zsh-hook precmd  jjprompt_precmd
  add-zsh-hook preexec jjprompt_preexec
  # Run our precmd FIRST so it captures $? before any other precmd hook (e.g. the
  # plugins above) can overwrite it; otherwise the symbol's color would be wrong.
  precmd_functions=(jjprompt_precmd ${precmd_functions:#jjprompt_precmd})

  # Leading newline = Pure-style spacing. Symbol color is exit-status driven
  # (computed in precmd); env name and SSH host shown around it.
  PROMPT='${jjprompt_newline}${jjprompt_host}%F{blue}%~%f${jjprompt_vcs}${jjprompt_exectime}${jjprompt_newline}${jjprompt_venv}${jjprompt_symcolor}${JJPROMPT_SYMBOL:-➜}%f '
  PROMPT2='%F{242}… %f'
}

jjprompt_setup
