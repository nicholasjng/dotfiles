# dotfiles

My personal dotfiles for macOS.

## Installation

```sh
git clone https://github.com/nicholasjunge/dotfiles
cd dotfiles
bash bootstrap.sh
```

If you clone elsewhere, set `DOTFILES_DIR` before running the script:

```sh
DOTFILES_DIR=/path/to/dotfiles bash bootstrap.sh
```

## Anatomy

Config files live under `.config/` in the repo, and mirror the XDG layout in `$HOME`. The bootstrap script:

1. Initialises git submodules (zsh plugins — pure, zsh-autosuggestions, zsh-syntax-highlighting)
2. Backs up any existing files to `$HOME/.local/state/dotfiles-backup/`
3. Creates symlinks from `$HOME` into the repo.

`.zshenv` sets `ZDOTDIR=$HOME/.config/zsh`, so zsh loads `.zprofile` and `.zshrc` from there instead of `$HOME`.

