#!/bin/zsh
set -eu

readonly LABEL="studio.yawaraka.session-tide"
readonly REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
readonly TEMPLATE="$REPO_DIR/launchd/${LABEL}.plist.template"
readonly TARGET="$HOME/Library/LaunchAgents/${LABEL}.plist"

mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs/session-tide"
chmod +x "$REPO_DIR/scripts/session-tide.zsh"

sed \
  -e "s#__REPO_DIR__#$REPO_DIR#g" \
  -e "s#__HOME__#$HOME#g" \
  "$TEMPLATE" > "$TARGET"

plutil -lint "$TARGET"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$TARGET"
launchctl enable "gui/$(id -u)/$LABEL"

print -r -- "Installed $LABEL"
print -r -- "Plist: $TARGET"
print -r -- "Log: $HOME/Library/Logs/session-tide/session-tide.log"
