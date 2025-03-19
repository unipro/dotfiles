#!/usr/bin/env bash

version_lt() {
    [ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" = "$1" ]
}

# List of dotfiles to manage
DOTFILES=(
    ".gitconfig"
)

# Backup existing dotfiles and copy new ones
for file in "${DOTFILES[@]}"; do
    if [ -f "$HOME/$file" ]; then
        echo "Backing up existing $file to $file.backup"
        mv "$HOME/$file" "$HOME/$file.backup"
    fi
    echo "Copying $file to home directory"
    cp "$file" "$HOME/$file"
done

# Ensure $HOME/.bashrc.d/init is sourced in $HOME/.bashrc
if [ -f "$HOME/.bashrc" ]; then
    if ! grep -q "\. ~/.bashrc.d/init" "$HOME/.bashrc"; then
        echo "Appending $HOME/.bashrc.d/init sourcing to $HOME/.bashrc"
        echo -e "\n# My bash configuration\nif [ -f ~/.bashrc.d/init ]; then\n    . ~/.bashrc.d/init\nfi" >> "$HOME/.bashrc"
    fi

    # Check if $HOME/.bashrc.d/init exists
    if [ ! -f "$HOME/.bashrc.d/init" ]; then
        echo "$HOME/.bashrc.d/init not found. To install it, run the following command:"
        echo "git clone https://github.com/unipro/.bashrc.d.git $HOME/.bashrc.d"
    fi
fi

GIT_VERSION=$(git --version | awk '{print $3}')
REQUIRED_VERSION="2.43.0"

# Ensure local git configuration is sourced
if [ ! -f "$HOME/.gitconfig.local" ]; then
    echo "Creating an empty .gitconfig.local for system-specific settings"
    touch "$HOME/.gitconfig.local"
fi

if version_lt "$GIT_VERSION" "$REQUIRED_VERSION"; then
    cat "$HOME/.gitconfig.local" >> "$HOME/.gitconfig"
else
    echo -e "\n#\n# An additional Git configuration file on the local machine.\n#" >> "$HOME/.gitconfig"
    echo -e "[includeIf \"exists:~/.gitconfig.local\"]\n\tpath = ~/.gitconfig.local" >> "$HOME/.gitconfig"
fi

echo "Dotfiles installation complete!"
