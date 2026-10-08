# dotfiles

My personal dotfiles for macOS.

## Installation

```sh
git clone https://github.com/nicholasjunge/dotfiles
cd dotfiles
bash bootstrap.sh
```

The script uses its own directory by default, wherever you clone the repo.
To use another checkout, set `DOTFILES_DIR`:

```sh
DOTFILES_DIR=/path/to/dotfiles bash bootstrap.sh
```

## Anatomy

Config files live under `.config/` in the repo, and mirror the XDG layout in `$HOME`. The bootstrap script:

1. Installs Homebrew if needed and installs packages from `Brewfile`.
2. Initialises git submodules (zsh plugins — zsh-autosuggestions, zsh-syntax-highlighting).
3. Moves existing files and symlinks into a unique directory under `$XDG_STATE_HOME/dotfiles-backup` (default `~/.local/state/dotfiles-backup`). Previous backups are preserved.
4. Creates symlinks from `$HOME` into the repo. Re-running leaves correct links in place.

`.zshenv` sets `ZDOTDIR=$HOME/.config/zsh`, so zsh loads `.zprofile` and `.zshrc` from there instead of `$HOME`.

The shell prompt is `jj-prompt` (`.config/zsh/plugins/jj-prompt`), a small dependency-free zsh prompt with first-class [jj](https://github.com/jj-vcs/jj) support and a git fallback.

Commit descriptions show the first line, truncated with `…` to at most 50 display
columns or half the terminal width, whichever is smaller. Set
`JJPROMPT_MAX_DESCRIPTION_LENGTH=30` in `.zshrc` before the prompt loads to change
the limit. `JJPROMPT_SYMBOL` changes the prompt symbol, and
`JJPROMPT_MAX_EXEC_TIME` sets the duration threshold in seconds (default 5).

Run `zsh_update_plugins` to update the plugin submodules to their upstream tips.
Commit the changed submodule references to keep other installations in sync.

## Helix

Run `helix-build` after bootstrap to build and install `hx` from upstream master.
Set `HELIX_SRC` to use a source directory other than `~/.local/src/helix`.
The script refuses to reset a checkout with local changes or commits that differ
from its recorded `origin/master` tip. It uses Cargo's lockfile and builds the
grammars selected in `.config/helix/languages.toml`.

The runtime directory is embedded in the binary at build time, following
[Helix's source-build instructions](https://docs.helix-editor.com/building-from-source.html),
so custom source locations also work outside a login shell. Re-run `helix-build`
to apply this to an existing installation. `HELIX_RUNTIME` can override that path.
