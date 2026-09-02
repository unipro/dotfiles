#!/usr/bin/env bash
#
# install.sh — copy this repo's dotfiles into $HOME, ~/.config and ~/.claude.
#
# With no arguments every component is installed. Pass component names to
# install only those, e.g. `install.sh bash doom`. Run with --list to see
# what is available.
#
set -eu

# Paths below are repo-relative, so run from the repo root regardless of
# where the script was invoked from.
cd "$(dirname "$0")"

# ─── Configuration ───────────────────────────────────────
# Installable components, in install order. Each name has a matching
# install_<name> function below ('-' in the name becomes '_').
COMPONENTS=(
    bash
    zsh
    shellenv
    git
    clang-format
    doom
    ghostty
    claude
)

# XDG config tree: dotconfig/<app>/... → $XDG_CONFIG_HOME/<app>/...
DOTCONFIG_DIR="dotconfig"
XDG_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"

# Claude Code keeps its config in ~/.claude, not the XDG tree, so it gets
# its own source directory. Only the hand-written files listed under
# dotclaude/ are managed; the runtime state Claude Code writes alongside
# them (sessions, history, caches) is never touched.
DOTCLAUDE_DIR="dotclaude"
CLAUDE_DIR="$HOME/.claude"

# The bash config (dotconfig/bash/{init,aliases,completion}) is sourced
# from the managed ~/.bashrc via init; the zsh config works the same way.
BASH_CONFIG_DIR="$XDG_CONFIG_DIR/bash"
ZSH_CONFIG_DIR="$XDG_CONFIG_DIR/zsh"

# The env generator is a command, not a config file, so it goes on PATH
# (~/.profile puts ~/.local/bin there) rather than into the XDG config tree.
# It writes both shells' env files, which is why it is its own component
# instead of a part of bash.
MKENV_SRC="bin/mkshellenv"
LOCAL_BIN_DIR="$HOME/.local/bin"

# Components requested on the command line, in COMPONENTS order.
SELECTED=()

# ─── Helpers ─────────────────────────────────────────────
usage() {
    cat >&2 <<'EOF'
Usage: install.sh [-h] [-l] [COMPONENT...]

Copy this repo's dotfiles into $HOME, ~/.config and ~/.claude. With no
COMPONENT given, every component is installed; `all` is an explicit alias
for that.

Options:
  -l, --list    List the installable components and exit
  -h, --help    Show this help and exit

Examples:
  ./install.sh              # install everything
  ./install.sh bash git     # only the shell and Git configs
  ./install.sh shellenv     # reinstall the env generator and re-run it
  ./install.sh doom         # only ~/.config/doom
  ./install.sh claude       # only ~/.claude/CLAUDE.md
EOF
}

# One line per component, kept in sync with COMPONENTS.
describe_component() {
    # The ~ below are literal display strings, not paths to expand.
    # shellcheck disable=SC2088
    case "$1" in
        bash)         echo '~/.bashrc ~/.bash_profile ~/.profile, ~/.config/bash/' ;;
        zsh)          echo '~/.zshrc, ~/.config/zsh/ (fallback shell)' ;;
        shellenv)     echo '~/.local/bin/mkshellenv, and the env files it generates for both shells' ;;
        git)          echo '~/.gitconfig (with ~/.gitconfig.local inlined)' ;;
        clang-format) echo '~/.clang-format' ;;
        doom)         echo '~/.config/doom/ (Doom Emacs)' ;;
        ghostty)      echo '~/.config/ghostty/' ;;
        claude)       echo '~/.claude/CLAUDE.md (two-way sync, newest wins)' ;;
    esac
}

list_components() {
    local name
    echo "Installable components:"
    for name in "${COMPONENTS[@]}"; do
        printf '  %-14s %s\n' "$name" "$(describe_component "$name")"
    done
}

is_component() {
    local name
    for name in "${COMPONENTS[@]}"; do
        [ "$name" = "$1" ] && return 0
    done
    return 1
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
    local requested=() name arg
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -l|--list)
                list_components
                exit 0
                ;;
            --)
                shift
                break
                ;;
            -*)
                echo "install.sh: unknown option '$1'" >&2
                usage
                exit 1
                ;;
            *)
                requested+=("$1")
                ;;
        esac
        shift
    done
    # Anything after `--` is a component name too.
    while [ $# -gt 0 ]; do
        requested+=("$1")
        shift
    done

    if [ ${#requested[@]} -eq 0 ]; then
        SELECTED=("${COMPONENTS[@]}")
        return 0
    fi

    for arg in "${requested[@]}"; do
        if [ "$arg" = "all" ]; then
            SELECTED=("${COMPONENTS[@]}")
            return 0
        fi
        is_component "$arg" || {
            echo "install.sh: unknown component '$arg'" >&2
            echo "Run 'install.sh --list' to see what is available." >&2
            exit 1
        }
    done

    # Walk COMPONENTS rather than the request, so the install order is
    # fixed and duplicate names collapse.
    for name in "${COMPONENTS[@]}"; do
        for arg in "${requested[@]}"; do
            if [ "$name" = "$arg" ]; then
                SELECTED+=("$name")
                break
            fi
        done
    done
}

# Copy src to dest. An existing target is moved aside to <dest>.backup,
# but a pre-existing backup is never overwritten — so re-running keeps
# the user's true original safe. A target that already matches the source
# is left completely alone.
copy_file() {
    local src="$1" dest="$2"

    # Nothing to install and nothing worth preserving: a backup here would
    # just duplicate the file it is backing up, and re-running install.sh
    # for one component would litter $HOME with copies of files that never
    # differed. Skipping the copy as well leaves mtimes untouched, which
    # keeps the newest-wins sync in sync_file honest.
    if [ -f "$dest" ] && cmp -s "$src" "$dest"; then
        echo "Unchanged: $(tilde "$dest")"
        return 0
    fi

    if [ -f "$dest" ] && [ ! -f "$dest.backup" ]; then
        echo "Backing up existing $(tilde "$dest") to $(tilde "$dest").backup"
        mv "$dest" "$dest.backup"
    fi
    mkdir -p "$(dirname "$dest")"
    echo "Copying $src to $(tilde "$dest")"
    cp "$src" "$dest"
}

# Copy every file under src_dir into dest_dir, preserving relative
# subpaths.
copy_tree() {
    local src_dir="$1" dest_dir="$2"
    [ -d "$src_dir" ] || return 0
    local src
    while IFS= read -r src; do
        copy_file "$src" "$dest_dir/${src#"$src_dir"/}"
    done < <(find "$src_dir" -type f)
}

# Sync one file between the repo and its installed copy: newest wins.
# Identical contents are left alone; otherwise the side with the more
# recent mtime overwrites the other. Copying the repo's version out goes
# through copy_file, so the local file is still backed up first.
#
# Caveat: git restamps files it checks out, so a file touched by `git
# pull` looks newer than an older local edit. Commit local changes (run
# this script first to pull them in) before pulling.
sync_file() {
    local repo="$1" installed="$2"

    if [ ! -f "$installed" ] || [ ! -f "$repo" ]; then
        copy_file "$repo" "$installed"
        return 0
    fi

    if cmp -s "$repo" "$installed"; then
        echo "Already in sync: $(tilde "$installed")"
    elif [ "$installed" -nt "$repo" ]; then
        echo "Copying newer $(tilde "$installed") into $repo"
        cp "$installed" "$repo"
    else
        copy_file "$repo" "$installed"
    fi
}

# Sync every file under src_dir with its counterpart in dest_dir. Only
# files present in the repo are considered, so unrelated files in
# dest_dir are ignored rather than pulled into the repo.
sync_tree() {
    local src_dir="$1" dest_dir="$2"
    [ -d "$src_dir" ] || return 0
    local src
    while IFS= read -r src; do
        sync_file "$src" "$dest_dir/${src#"$src_dir"/}"
    done < <(find "$src_dir" -type f)
}

# ─── Components ──────────────────────────────────────────
# Shell startup files and the XDG bash config. The machine-specific env
# file it loads comes from the shellenv component.
install_bash() {
    local file
    for file in ".bashrc" ".bash_profile" ".profile"; do
        copy_file "$file" "$HOME/$file"
    done
    copy_tree "$DOTCONFIG_DIR/bash" "$BASH_CONFIG_DIR"
}

# The zsh side of the same setup: ~/.zshrc plus ~/.config/zsh/. Install this
# on its own and the init script simply skips a missing env file until
# `mkshellenv' is next run.
install_zsh() {
    copy_file ".zshrc" "$HOME/.zshrc"
    copy_tree "$DOTCONFIG_DIR/zsh" "$ZSH_CONFIG_DIR"
}

# The env generator, plus the machine-specific files it writes
# (~/.config/bash/env and ~/.config/zsh/env), regenerated from the freshly
# installed copy.
install_shellenv() {
    local dest="$LOCAL_BIN_DIR/mkshellenv"
    copy_file "$MKENV_SRC" "$dest"
    chmod +x "$dest"

    # Retire the copy earlier versions installed into the XDG config tree,
    # where it was both misfiled (a command among config files) and misnamed
    # (it is not bash-only). A .backup beside it is left alone.
    local stale="$BASH_CONFIG_DIR/mkenv"
    if [ -f "$stale" ]; then
        echo "Removing superseded $(tilde "$stale")"
        rm -f "$stale"
    fi

    echo "Generating shell env via $(tilde "$dest")"
    bash "$dest"
}

# ~/.gitconfig, with the machine-local ~/.gitconfig.local inlined at the
# end. The append is only idempotent because the copy restores a pristine
# .gitconfig first, so these two steps must stay together.
install_git() {
    copy_file ".gitconfig" "$HOME/.gitconfig"

    if [ ! -f "$HOME/.gitconfig.local" ]; then
        echo "Creating an empty .gitconfig.local for system-specific settings"
        touch "$HOME/.gitconfig.local"
    fi
    printf '\n#\n# An additional Git configuration file on the local machine.\n#\n' \
        >>"$HOME/.gitconfig"
    cat "$HOME/.gitconfig.local" >>"$HOME/.gitconfig"
}

install_clang_format() {
    copy_file ".clang-format" "$HOME/.clang-format"
}

install_doom() {
    copy_tree "$DOTCONFIG_DIR/doom" "$XDG_CONFIG_DIR/doom"
}

install_ghostty() {
    copy_tree "$DOTCONFIG_DIR/ghostty" "$XDG_CONFIG_DIR/ghostty"
}

# Claude Code's global rules (~/.claude/CLAUDE.md). This is the one
# component that syncs both ways: the rules are edited in place from a
# session about as often as they are edited in the repo, so the newer
# side wins instead of the repo always overwriting the installed copy.
install_claude() {
    sync_tree "$DOTCLAUDE_DIR" "$CLAUDE_DIR"
}

main() {
    parse_args "$@"
    local name
    for name in "${SELECTED[@]}"; do
        echo "── ${name} ──"
        "install_${name//-/_}"
    done
    echo "Dotfiles installation complete: ${SELECTED[*]}"
}

main "$@"
