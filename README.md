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
2. Backs up any existing files to `backup/`
1. Initialises git submodules (zsh plugins — zsh-autosuggestions, zsh-syntax-highlighting)
2. Backs up any existing files to `backup/`
3. Creates symlinks from `$HOME` into the repo.

`.zshenv` sets `ZDOTDIR=$HOME/.config/zsh`, so zsh loads `.zprofile` and `.zshrc` from there instead of `$HOME`.

The shell prompt is `jj-prompt` (`.config/zsh/plugins/jj-prompt`), a small dependency-free zsh prompt with first-class [jj](https://github.com/jj-vcs/jj) support and a git fallback. It lives in-repo rather than as a submodule.

