#!/bin/bash
# Installs Ask Claude into GNOME Files' right-click Scripts menu for the current user.
set -eu
dest="${XDG_DATA_HOME:-$HOME/.local/share}/nautilus/scripts"
mkdir -p "$dest"
install -m 755 "$(dirname "$0")/ask-claude" "$dest/Ask Claude"
echo "Installed: $dest/Ask Claude"
echo "Right-click a file or folder in Files → Scripts → Ask Claude"
