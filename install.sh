#!/usr/bin/env bash
set -euo pipefail

INSTALL_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PREFIX="${PREFIX:-/usr/local}"
BIN="$PREFIX/bin"
LIB="$PREFIX/lib/sshx"

echo "Installing sshx to $BIN..."

# Create lib dir
mkdir -p "$LIB"
cp -r "$INSTALL_SCRIPT_DIR/lib/"* "$LIB/"

# Patch lib path in main script
sed \
    -e "s|^SCRIPT_DIR=.*|SCRIPT_DIR=\"$LIB\"|" \
    -e "s|^LIB_DIR=.*|LIB_DIR=\"$LIB\"|"       \
    "$INSTALL_SCRIPT_DIR/sshx" > "$BIN/sshx"
    
chmod 755 "$BIN/sshx"

echo "✓ Installed sshx $("$BIN/sshx" version)"
echo ""
echo "Run 'sshx init' to initialize ~/.sshx"
echo "Then add shell completions:"
echo "  sshx completion bash >> ~/.bashrc"
echo "  sshx completion zsh  >> ~/.zshrc"
echo "  sshx completion fish > ~/.config/fish/completions/sshx.fish"

