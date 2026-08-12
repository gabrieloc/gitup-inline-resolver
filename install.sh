#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_FILE="$SCRIPT_DIR/gitup.zsh"
TARGET_DIR="$HOME/.config/gitup"
TARGET_FILE="$TARGET_DIR/gitup.zsh"
ZSHRC="$HOME/.zshrc"

START_MARK="# >>> gitup inline resolver >>>"
END_MARK="# <<< gitup inline resolver <<<"
SOURCE_LINE='source "$HOME/.config/gitup/gitup.zsh"'

if [[ ! -f "$SOURCE_FILE" ]]; then
  echo "Missing source file: $SOURCE_FILE" >&2
  exit 1
fi

mkdir -p "$TARGET_DIR"
cp "$SOURCE_FILE" "$TARGET_FILE"
echo "Installed: $TARGET_FILE"

if [[ ! -f "$ZSHRC" ]]; then
  touch "$ZSHRC"
fi

if grep -Fq "$START_MARK" "$ZSHRC"; then
  echo "zshrc block already present: $ZSHRC"
else
  cp "$ZSHRC" "$ZSHRC.bak.$(date +%Y%m%d%H%M%S)"
  {
    echo
    echo "$START_MARK"
    echo 'if [[ -f "$HOME/.config/gitup/gitup.zsh" ]]; then'
    echo "  $SOURCE_LINE"
    echo "fi"
    echo "$END_MARK"
  } >> "$ZSHRC"
  echo "Updated: $ZSHRC"
fi

echo "Done. Open a new shell or run: source ~/.zshrc"
