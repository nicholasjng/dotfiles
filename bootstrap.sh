#!/usr/bin/env bash
set -euo pipefail

info()    { printf '\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
success() { printf '\033[1;32m  ✓\033[0m %s\n' "$*"; }
backup()  { printf '\033[1;33m  ·\033[0m Backing up %s\n' "$*"; }
error()   { printf '\033[1;31mError:\033[0m %s\n' "$*" >&2; }

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "$0")" && pwd)}"

if [[ ! -e "$DOTFILES_DIR/.git" ]]; then
    error "Dotfiles repo not found at $DOTFILES_DIR"
    error "Clone it first, or set DOTFILES_DIR to its location."
    exit 1
fi
DOTFILES_DIR="$(cd "$DOTFILES_DIR" && pwd)"

# Homebrew may be installed without being on PATH.
if ! command -v brew >/dev/null; then
    for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        if [[ -x "$brew_bin" ]]; then
            eval "$("$brew_bin" shellenv)"
            break
        fi
    done
fi

if ! command -v brew >/dev/null; then
    info "Homebrew not found, installing..."
    installer="$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    NONINTERACTIVE=1 /bin/bash -c "$installer"
    case "$(uname -m)" in
        arm64) eval "$(/opt/homebrew/bin/brew shellenv)" ;;
        *)     eval "$(/usr/local/bin/brew shellenv)" ;;
    esac
fi

info "Installing Homebrew packages..."
brew bundle install --no-upgrade --file="$DOTFILES_DIR/Brewfile"

info "Initialising submodules..."
git -C "$DOTFILES_DIR" submodule update --init --recursive

backup_root="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles-backup"
backup_dir=''

# Moving preserves symlinks; unique directories preserve earlier backups.
backup_and_remove() {
    local target="$1" dest
    if [[ -e "$target" || -L "$target" ]]; then
        if [[ -z "$backup_dir" ]]; then
            mkdir -p "$backup_root"
            backup_dir="$(mktemp -d "$backup_root/$(date +%Y%m%d-%H%M%S).XXXXXX")"
        fi
        dest="$backup_dir/${2:-$(basename "$target")}"
        backup "$target → $dest"
        mv "$target" "$dest"
    fi
}

# Move the target first; ln follows symlinks to directories.
link_config() {
    local source="$DOTFILES_DIR/$1" target="$2" name="$3"
    if [[ -L "$target" && "$(readlink "$target")" == "$source" ]]; then
        return
    fi
    mkdir -p "$(dirname "$target")"
    backup_and_remove "$target" "$name"
    ln -s "$source" "$target"
}

info "Creating symlinks..."
link_config .zshenv "$HOME/.zshenv" .zshenv
# ZDOTDIR supersedes these files.
backup_and_remove "$HOME/.zshrc"
backup_and_remove "$HOME/.zprofile"

link_config .config/zsh                  "$HOME/.config/zsh"                  zsh
link_config .config/ghostty/config       "$HOME/.config/ghostty/config"       ghostty_config
link_config .config/helix/languages.toml "$HOME/.config/helix/languages.toml" helix_languages.toml
link_config .config/jj/config.toml       "$HOME/.config/jj/config.toml"       jj_config.toml
link_config .config/zed/settings.json    "$HOME/.config/zed/settings.json"    zed_settings.json
link_config bin/helix-build              "$HOME/.local/bin/helix-build"       helix_build_script

success "Done. Open a new shell to pick up the new config."
