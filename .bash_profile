# ~/.bash_profile: executed by bash(1) for login shells.
# dotfiles-managed: install.sh replaces this file wholesale.
# shellcheck shell=bash
#
# Cross-platform (macOS and Linux). Bootstraps Homebrew when present,
# pulls in the POSIX login setup from ~/.profile, then hands off to
# ~/.bashrc for the interactive configuration.

# Homebrew: bring brew onto PATH before anything else needs it.
if [ -x /opt/homebrew/bin/brew ]; then
    # Apple Silicon macOS
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
    # Intel macOS
    eval "$(/usr/local/bin/brew shellenv)"
elif [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
    # Linuxbrew
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# Login-shell environment (PATH additions, etc.).
if [ -f "$HOME/.profile" ]; then
    # shellcheck source=/dev/null
    . "$HOME/.profile"
fi

# Interactive configuration.
if [ -f "$HOME/.bashrc" ]; then
    # shellcheck source=/dev/null
    . "$HOME/.bashrc"
fi

# Local Variables:
# mode: shell-script
# End:
