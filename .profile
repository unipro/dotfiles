# ~/.profile: executed by the command interpreter for login shells.
# dotfiles-managed: install.sh replaces this file wholesale.
# shellcheck shell=sh
#
# Cross-platform and POSIX sh compatible. Bash login shells reach this
# file through ~/.bash_profile; it deliberately does NOT source
# ~/.bashrc (that is ~/.bash_profile's job) to avoid double-sourcing.

# Set PATH so it includes the user's private bin directories.
if [ -d "$HOME/bin" ]; then
    PATH="$HOME/bin:$PATH"
fi
if [ -d "$HOME/.local/bin" ]; then
    PATH="$HOME/.local/bin:$PATH"
fi
export PATH

# Rust / cargo environment.
if [ -f "$HOME/.cargo/env" ]; then
    # shellcheck source=/dev/null
    . "$HOME/.cargo/env"
fi

# Local Variables:
# mode: shell-script
# End:
