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

# Marker that identifies a shell startup file as this repo's own copy.
# install.sh replaces a file carrying it and never replaces one that does
# not: a foreign ~/.bashrc (company image, distro default, another dotfiles
# manager) gets the wiring block appended instead, so it keeps working.
RC_MARKER="dotfiles-managed"

# Components requested on the command line, in COMPONENTS order.
SELECTED=()

# --force-rc: treat an existing startup file as ours even without the
# marker. The rescue hatch for a file installed before the marker existed,
# or one edited past recognition.
FORCE_RC=0

# ─── Helpers ─────────────────────────────────────────────
usage() {
    cat >&2 <<'EOF'
Usage: install.sh [-h] [-l] [COMPONENT...]

Copy this repo's dotfiles into $HOME, ~/.config and ~/.claude. With no
COMPONENT given, every component is installed; `all` is an explicit alias
for that.

A shell startup file (~/.bashrc, ~/.bash_profile, ~/.profile, ~/.zshrc)
is only replaced when it is absent or carries this repo's marker. Any
other file is yours: the loader for ~/.config/<shell>/init is appended to
it and the rest is left untouched.

Options:
  -f, --force-rc  Replace startup files even without the marker
  -l, --list      List the installable components and exit
  -h, --help      Show this help and exit

Examples:
  ./install.sh              # install everything
  ./install.sh bash git     # only the shell and Git configs
  ./install.sh shellenv     # reinstall the env generator and re-run it
  ./install.sh doom         # only ~/.config/doom
  ./install.sh claude       # only ~/.claude/CLAUDE.md
  ./install.sh -f bash      # take over an unmarked ~/.bashrc
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
            -f|--force-rc)
                FORCE_RC=1
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
# True when dest's contents match some version of src this repository has
# committed -- so it is a copy install.sh shipped at some point rather than
# something the user wrote. Replacing one of those needs no backup: git
# history already holds it. Anything else is treated as the user's own.
was_shipped() {
    local src="$1" dest="$2" rev
    command -v git >/dev/null 2>&1 || return 1
    git rev-parse --git-dir >/dev/null 2>&1 || return 1
    for rev in $(git log --follow --format=%H -- "$src"); do
        if git show "$rev:$src" 2>/dev/null | cmp -s - "$dest"; then
            return 0
        fi
    done
    return 1
}

# Move an existing target aside to <dest>.backup, unless a backup is
# already there -- that one is the user's true original and outranks any
# later state.
backup_file() {
    local dest="$1"
    if [ -f "$dest" ] && [ ! -f "$dest.backup" ]; then
        echo "Backing up existing $(tilde "$dest") to $(tilde "$dest").backup"
        cp "$dest" "$dest.backup"
    fi
}

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

    # No backup for a file this repo shipped: it would only preserve an older
    # version of a tracked file, which is what the history is for. That keeps
    # a change to a managed file from dropping a .backup on every machine.
    if ! was_shipped "$src" "$dest"; then
        backup_file "$dest"
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

# Install one shell startup file, without clobbering a file this repo did
# not write. In order:
#
#   1. absent                    -> install the repo's copy
#   2. carries RC_MARKER, or is a
#      version this repo shipped -> ours, so keep it current
#   3. --force-rc given          -> treat it as ours anyway
#   4. already sources $3        -> wired already; leave it exactly as is
#   5. anything else             -> yours: append the loader, nothing more
#
# Case 2 checks the history as well as the marker so that a copy installed
# before the marker existed is still recognized; without that it would look
# foreign, be found already wired, and never see another update again.
#
# $3 is the $HOME-relative path the file has to end up sourcing; pass "" for
# a file that carries no hook (~/.profile), which then falls through to being
# left alone.
install_rc() {
    local src="$1" dest="$2" wire="$3"

    if [ ! -f "$dest" ]; then
        copy_file "$src" "$dest"
        return 0
    fi

    if grep -q "$RC_MARKER" "$dest" || was_shipped "$src" "$dest" \
           || [ "$FORCE_RC" = 1 ]; then
        copy_file "$src" "$dest"
        return 0
    fi

    if [ -z "$wire" ]; then
        echo "Keeping your own $(tilde "$dest") (nothing to wire)"
        return 0
    fi

    # A sourcing line, not a mention: the path has to be preceded by `.' or
    # `source' on a line that is not a comment, so a "see also ~/.bashrc"
    # remark does not read as already wired.
    if grep -qE "^[^#]*(\.|source)[[:space:]].*${wire//./\\.}" "$dest"; then
        echo "Already wired: $(tilde "$dest") sources ~/$wire"
        return 0
    fi

    echo "Wiring ~/$wire into your own $(tilde "$dest")"
    backup_file "$dest"
    cat >>"$dest" <<EOF

# Added by the dotfiles install script -- load the shell configuration in
# ~/.config. Delete this block to unhook it.
if [ -f "\$HOME/$wire" ]; then
    . "\$HOME/$wire"
fi
EOF
}

# ─── Components ──────────────────────────────────────────
# Shell startup files and the XDG bash config. The machine-specific env
# file it loads comes from the shellenv component.
install_bash() {
    # ~/.bash_profile is wired to ~/.bashrc rather than to the init script:
    # macOS terminals start login shells, which read only .bash_profile, so
    # without that hop the .bashrc wiring below would never fire.
    install_rc ".bash_profile" "$HOME/.bash_profile" ".bashrc"
    install_rc ".bashrc" "$HOME/.bashrc" ".config/bash/init"
    install_rc ".profile" "$HOME/.profile" ""
    copy_tree "$DOTCONFIG_DIR/bash" "$BASH_CONFIG_DIR"
}

# The zsh side of the same setup: ~/.zshrc plus ~/.config/zsh/. Install this
# on its own and the init script simply skips a missing env file until
# `mkshellenv' is next run.
install_zsh() {
    install_rc ".zshrc" "$HOME/.zshrc" ".config/zsh/init"
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
