export ZDOTDIR="$HOME/.config/zsh"

# Point at the runtime dir of the local source build (see bin/helix-build).
# In .zshenv rather than .zprofile so it's set for every shell, not just
# login shells (hx can be invoked from non-login contexts too).
if [[ -z "$HELIX_RUNTIME" && -d "$HOME/.local/src/helix/runtime" ]]; then
  export HELIX_RUNTIME="$HOME/.local/src/helix/runtime"
fi
