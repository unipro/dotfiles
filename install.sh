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
    ".bashrc"
    ".bash_profile"
    ".profile"
)

# XDG config tree: dotconfig/<app>/... → $XDG_CONFIG_HOME/<app>/...
# The bash config (dotconfig/bash/{init,aliases,completion}) is sourced
# from the managed ~/.bashrc via init.
DOTCONFIG_DIR="dotconfig"
XDG_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"

# The mkenv generator is installed alongside the bash config; it
# regenerates the machine-specific env file.
MKENV_SRC="mkenv"
BASH_CONFIG_DIR="$XDG_CONFIG_DIR/bash"

# Git gained `includeIf "exists:..."` in 2.43.0. On older Git we
# inline .gitconfig.local instead of including it by reference.
REQUIRED_GIT_VERSION="2.43.0"

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

# Display a path with $HOME collapsed to ~ for tidier messages.
tilde() {
    # The ~ below is a literal display string, not a path to expand.
    # shellcheck disable=SC2088
    case "$1" in
        "$HOME"/*) printf '~/%s' "${1#"$HOME"/}" ;;
        *)         printf '%s' "$1" ;;
    esac
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

# Copy every file under src_dir into dest_dir, preserving relative
# subpaths. An existing target is moved aside to <file>.backup, but a
# pre-existing backup is never overwritten — so re-running keeps the
# user's true original safe.
copy_tree() {
    local src_dir="$1" dest_dir="$2"
    [ -d "$src_dir" ] || return 0
    local src rel dest
    while IFS= read -r src; do
        rel="${src#"$src_dir"/}"
        dest="$dest_dir/$rel"
        if [ -f "$dest" ] && [ ! -f "$dest.backup" ]; then
            echo "Backing up existing $(tilde "$dest") to $(tilde "$dest").backup"
            mv "$dest" "$dest.backup"
        fi
        mkdir -p "$(dirname "$dest")"
        echo "Copying $rel to $(tilde "$dest_dir")"
        cp "$src" "$dest"
    done < <(find "$src_dir" -type f)
}

# Copy the managed dotfiles into $HOME.
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

# Mirror dotconfig/ into ~/.config and install the mkenv generator
# into ~/.config/bash alongside it. An existing mkenv is moved aside to
# mkenv.backup (a pre-existing backup is never overwritten).
install_config() {
    copy_tree "$DOTCONFIG_DIR" "$XDG_CONFIG_DIR"

    local dest="$BASH_CONFIG_DIR/mkenv"
    if [ -f "$dest" ] && [ ! -f "$dest.backup" ]; then
        echo "Backing up existing $(tilde "$dest") to $(tilde "$dest").backup"
        mv "$dest" "$dest.backup"
    fi
    mkdir -p "$BASH_CONFIG_DIR"
    echo "Copying $MKENV_SRC to $(tilde "$BASH_CONFIG_DIR")"
    cp "$MKENV_SRC" "$dest"
}

# (Re)generate the machine-specific env files (~/.config/bash/env and
# ~/.config/zsh/env) from the freshly installed mkenv.
generate_shell_env() {
    local mkenv="$BASH_CONFIG_DIR/mkenv"
    [ -x "$mkenv" ] || return 0
    echo "Generating shell env via $(tilde "$mkenv")"
    bash "$mkenv"
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
    install_config
    generate_shell_env
    configure_git_local
    echo "Dotfiles installation complete!"
}

main "$@"
