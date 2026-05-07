#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"

if [[ ! -d "$DOTFILES_DIR/.git" ]]; then
    echo "Dotfiles repo not found at $DOTFILES_DIR"
    echo "Clone it first, or set DOTFILES_DIR to its location."
    exit 1
fi

echo "Initialising submodules..."
git -C "$DOTFILES_DIR" submodule update --init --recursive

backup_dir="$DOTFILES_DIR/backup"
mkdir -p "$backup_dir" "$HOME/.config"

# Back up a file or directory to the backup dir, then remove it.
backup_and_remove() {
    local target="$1" dest="$backup_dir/${2:-$(basename "$1")}"
    if [[ -e "$target" && ! -L "$target" ]]; then
        echo "Backing up $target -> $dest"
        cp -r "$target" "$dest"
        rm -rf "$target"
    fi
}

echo "Creating symlinks..."

# ~/.zshenv
backup_and_remove "$HOME/.zshenv"
ln -sf "$DOTFILES_DIR/.zshenv" "$HOME/.zshenv"

# ~/.zshrc and ~/.zprofile (superseded by ZDOTDIR)
backup_and_remove "$HOME/.zshrc"
backup_and_remove "$HOME/.zprofile"

# ~/.config/zsh (whole directory — no runtime data mixed in)
if [[ -d "$HOME/.config/zsh" && ! -L "$HOME/.config/zsh" ]]; then
    backup_and_remove "$HOME/.config/zsh" "zsh"
fi
ln -sf "$DOTFILES_DIR/.config/zsh" "$HOME/.config/zsh"

# Individual config files
mkdir -p "$HOME/.config/ghostty" "$HOME/.config/helix" "$HOME/.config/jj"

backup_and_remove "$HOME/.config/ghostty/config"       "ghostty_config"
backup_and_remove "$HOME/.config/helix/languages.toml" "helix_languages.toml"
backup_and_remove "$HOME/.config/jj/config.toml"       "jj_config.toml"

ln -sf "$DOTFILES_DIR/.config/ghostty/config"       "$HOME/.config/ghostty/config"
ln -sf "$DOTFILES_DIR/.config/helix/languages.toml" "$HOME/.config/helix/languages.toml"
ln -sf "$DOTFILES_DIR/.config/jj/config.toml"       "$HOME/.config/jj/config.toml"

echo "Done. Open a new shell to pick up the new config."
