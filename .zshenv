export ZDOTDIR="$HOME/.config/zsh"

# Runtime fallback for older binaries built in the default checkout.
if [[ -z "$HELIX_RUNTIME" && -d "$HOME/.local/src/helix/runtime" &&
      "$HOME/.local/bin/hx" -ef "$HOME/.local/src/helix/target/release/hx" ]]; then
  export HELIX_RUNTIME="$HOME/.local/src/helix/runtime"
fi
