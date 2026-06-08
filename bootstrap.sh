#!/usr/bin/env bash
set -euo pipefail

info()    { printf '\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
success() { printf '\033[1;32m  ✓\033[0m %s\n' "$*"; }
backup()  { printf '\033[1;33m  ·\033[0m Backing up %s\n' "$*"; }
error()   { printf '\033[1;31mError:\033[0m %s\n' "$*" >&2; }

# Default to the directory this script lives in, so the repo can be moved
# anywhere without the symlinks drifting. Override with DOTFILES_DIR=... if needed.
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "$0")" && pwd)}"

if [[ ! -d "$DOTFILES_DIR/.git" ]]; then
    error "Dotfiles repo not found at $DOTFILES_DIR"
    error "Clone it first, or set DOTFILES_DIR to its location."
    exit 1
fi

if ! command -v brew >/dev/null; then
    info "Homebrew not found, installing..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

info "Installing Homebrew packages..."
brew bundle install --no-upgrade --file="$DOTFILES_DIR/Brewfile"

info "Initialising submodules..."
git -C "$DOTFILES_DIR" submodule update --init --recursive

backup_dir="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles-backup"
mkdir -p "$backup_dir" "$HOME/.config"

# Back up a file or directory to the backup dir, then remove it.
backup_and_remove() {
    local target="$1" dest="$backup_dir/${2:-$(basename "$1")}"
    if [[ -e "$target" && ! -L "$target" ]]; then
        backup "$target → $dest"
        cp -r "$target" "$dest"
        rm -rf "$target"
    fi
}

info "Creating symlinks..."

# ~/.zshenv
backup_and_remove "$HOME/.zshenv"
ln -sf "$DOTFILES_DIR/.zshenv" "$HOME/.zshenv"

# ~/.zshrc and ~/.zprofile (superseded by ZDOTDIR)
backup_and_remove "$HOME/.zshrc"
backup_and_remove "$HOME/.zprofile"

# ~/.config/zsh (whole directory). Remove an existing symlink first, else
# `ln -sf` would dereference it and link inside the target.
if [[ -L "$HOME/.config/zsh" ]]; then
    rm -f "$HOME/.config/zsh"
elif [[ -d "$HOME/.config/zsh" ]]; then
    backup_and_remove "$HOME/.config/zsh" "zsh"
fi
ln -sf "$DOTFILES_DIR/.config/zsh" "$HOME/.config/zsh"

# Individual config files
mkdir -p "$HOME/.config/ghostty"
mkdir -p "$HOME/.config/helix"
mkdir -p "$HOME/.config/jj"
mkdir -p "$HOME/.config/zed"
mkdir -p "$HOME/.local/bin"

backup_and_remove "$HOME/.config/ghostty/config"       "ghostty_config"
backup_and_remove "$HOME/.config/helix/languages.toml" "helix_languages.toml"
backup_and_remove "$HOME/.config/jj/config.toml"       "jj_config.toml"
backup_and_remove "$HOME/.config/zed/settings.json"    "zed_settings.json"
backup_and_remove "$HOME/.local/bin/helix-build"       "helix_build_script"

ln -sf "$DOTFILES_DIR/.config/ghostty/config"       "$HOME/.config/ghostty/config"
ln -sf "$DOTFILES_DIR/.config/helix/languages.toml" "$HOME/.config/helix/languages.toml"
ln -sf "$DOTFILES_DIR/.config/jj/config.toml"       "$HOME/.config/jj/config.toml"
ln -sf "$DOTFILES_DIR/.config/zed/settings.json"    "$HOME/.config/zed/settings.json"
ln -sf "$DOTFILES_DIR/bin/helix-build"              "$HOME/.local/bin/helix-build"

success "Done. Open a new shell to pick up the new config."
