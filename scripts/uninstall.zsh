#!/bin/zsh
set -eu

readonly LABEL="studio.yawaraka.session-tide"
readonly TARGET="$HOME/Library/LaunchAgents/${LABEL}.plist"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$TARGET"

print -r -- "Uninstalled $LABEL"
