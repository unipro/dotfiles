#!/usr/bin/env bash
#
# install.sh — copy this repo's dotfiles into $HOME and ~/.config.
#
set -eu

# ─── Configuration ───────────────────────────────────────
# Dotfiles to copy into $HOME (relative to this repo).
DOTFILES=(
    ".gitconfig"
    ".clang-format"
)

# XDG config tree: dotconfig/<app>/... → $XDG_CONFIG_HOME/<app>/...
DOTCONFIG_DIR="dotconfig"
XDG_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"

# Git gained `includeIf "exists:..."` in 2.43.0. On older Git we
# inline .gitconfig.local instead of including it by reference.
REQUIRED_GIT_VERSION="2.43.0"

# Repo where the sourced ~/.bashrc.d/init lives.
BASHRC_D_REPO="https://github.com/unipro/.bashrc.d.git"

APPEND_GITLOCAL=0

# ─── Helpers ─────────────────────────────────────────────
usage() {
    cat >&2 <<'EOF'
Usage: install.sh [--append-gitlocal]
  --append-gitlocal, -a   : appending .gitconfig.local to the end of .gitconfig
EOF
}

# version_lt A B → true when version A is strictly older than B.
version_lt() {
    [ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" = "$1" ] && [ "$1" != "$2" ]
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -a|--append-gitlocal)
                APPEND_GITLOCAL=1
                ;;
            --)
                shift
                break
                ;;
            *)
                usage
                exit 1
                ;;
        esac
        shift
    done
}

# Copy each managed dotfile into $HOME, preserving the original (if
# any) as <file>.backup. An existing backup is never overwritten, so
# re-running the script keeps the user's true original safe.
install_dotfiles() {
    local file
    for file in "${DOTFILES[@]}"; do
        if [ -f "$HOME/$file" ] && [ ! -f "$HOME/$file.backup" ]; then
            echo "Backing up existing $file to $file.backup"
            mv "$HOME/$file" "$HOME/$file.backup"
        fi
        echo "Copying $file to home directory"
        cp "$file" "$HOME/$file"
    done
}

# Mirror the dotconfig/ tree into $XDG_CONFIG_DIR (~/.config by
# default), preserving any existing file as <file>.backup. An existing
# backup is never overwritten, so re-running keeps the original safe.
install_dotconfig() {
    [ -d "$DOTCONFIG_DIR" ] || return 0
    local src rel dest
    while IFS= read -r src; do
        rel="${src#"$DOTCONFIG_DIR"/}"
        dest="$XDG_CONFIG_DIR/$rel"
        if [ -f "$dest" ] && [ ! -f "$dest.backup" ]; then
            echo "Backing up existing .config/$rel to .config/$rel.backup"
            mv "$dest" "$dest.backup"
        fi
        mkdir -p "$(dirname "$dest")"
        echo "Copying $rel to $XDG_CONFIG_DIR"
        cp "$src" "$dest"
    done < <(find "$DOTCONFIG_DIR" -type f)
}

# Make sure ~/.bashrc sources ~/.bashrc.d/init, and point the user at
# the repo if that init script isn't present yet.
ensure_bashrc_init() {
    [ -f "$HOME/.bashrc" ] || return 0

    if ! grep -q "\. ~/.bashrc.d/init" "$HOME/.bashrc"; then
        echo "Appending $HOME/.bashrc.d/init sourcing to $HOME/.bashrc"
        cat >>"$HOME/.bashrc" <<'EOF'

# My bash configuration
if [ -f ~/.bashrc.d/init ]; then
    . ~/.bashrc.d/init
fi
EOF
    fi

    if [ ! -f "$HOME/.bashrc.d/init" ]; then
        echo "$HOME/.bashrc.d/init not found. To install it, run the following command:"
        echo "git clone $BASHRC_D_REPO $HOME/.bashrc.d"
    fi
}

# Wire up the machine-local Git config. Modern Git includes it by
# reference; older Git inlines it (so does --append-gitlocal).
configure_git_local() {
    local git_version
    git_version=$(git --version | awk '{print $3}')

    if [ ! -f "$HOME/.gitconfig.local" ]; then
        echo "Creating an empty .gitconfig.local for system-specific settings"
        touch "$HOME/.gitconfig.local"
    fi

    printf '\n#\n# An additional Git configuration file on the local machine.\n#\n' \
        >>"$HOME/.gitconfig"

    if [ "$APPEND_GITLOCAL" -eq 1 ] || version_lt "$git_version" "$REQUIRED_GIT_VERSION"; then
        cat "$HOME/.gitconfig.local" >>"$HOME/.gitconfig"
    else
        printf '[includeIf "exists:~/.gitconfig.local"]\n\tpath = ~/.gitconfig.local\n' \
            >>"$HOME/.gitconfig"
    fi
}

main() {
    parse_args "$@"
    install_dotfiles
    install_dotconfig
    ensure_bashrc_init
    configure_git_local
    echo "Dotfiles installation complete!"
}

main "$@"
