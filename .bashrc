# ~/.bashrc: executed by bash(1) for interactive non-login shells.
# dotfiles-managed: install.sh replaces this file wholesale. Machine-local
# settings belong in ~/.config/bash/aliases or ~/.config/bash/private.
# shellcheck shell=bash
#
# Cross-platform (macOS and Linux). Machine-specific environment is
# generated into ~/.config/bash/env by mkenv and loaded via the init
# script sourced at the end of this file.

# If not running interactively, don't do anything.
case $- in
    *i*) ;;
      *) return;;
esac

# Source global definitions.
if [ -f /etc/bashrc ]; then
    # shellcheck source=/dev/null
    . /etc/bashrc
elif [ -f /etc/bash.bashrc ]; then
    # shellcheck source=/dev/null
    . /etc/bash.bashrc
fi

# History: don't store duplicate lines or lines starting with a space,
# append rather than overwrite, and keep a reasonable backlog.
HISTCONTROL=ignoreboth
HISTSIZE=1000
HISTFILESIZE=2000
shopt -s histappend

# Check the window size after each command and update LINES/COLUMNS.
shopt -s checkwinsize

# Make less more friendly for non-text input files (Linux lesspipe).
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# Prompt: colored when the terminal advertises color support.
case "$TERM" in
    xterm-*color|*-256color)
        PS1='[\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\W\[\033[00m\]]\$ '
        ;;
    *)
        PS1='[\u@\h:\W]\$ '
        ;;
esac

# If this is an xterm, set the title to user@host:dir.
case "$TERM" in
    xterm*|rxvt*)
        PROMPT_COMMAND='echo -ne "\033]0;${USER}@${HOSTNAME}: ${PWD/#$HOME/~}\007"'
        ;;
    *)
        ;;
esac

# Color support for ls and friends, and a couple of platform tweaks.
case "$OSTYPE" in
    linux-gnu*)
        if command -v dircolors >/dev/null 2>&1; then
            test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" \
                || eval "$(dircolors -b)"
        fi
        alias ls='ls --color=auto'
        alias grep='grep --color=auto'
        alias fgrep='fgrep --color=auto'
        alias egrep='egrep --color=auto'
        ;;
    darwin*|*bsd*)
        alias ls='ls -G'
        ;;
esac

# Some more ls aliases.
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Machine-local alias definitions (not tracked in dotfiles).
if [ -f ~/.bash_aliases ]; then
    # shellcheck source=/dev/null
    . ~/.bash_aliases
fi

# My bash configuration (cross-platform; loads ~/.config/bash/*).
if [ -f ~/.config/bash/init ]; then
    # shellcheck source=/dev/null
    . ~/.config/bash/init
fi

# Local Variables:
# mode: shell-script
# End:
