#!/bin/bash
# Codepet Extension — Clean Reinstall Script
# This removes ALL cached versions and installs fresh.

echo "=== Codepet Clean Reinstall ==="

# Step 1: Uninstall via Cursor CLI
echo "[1/4] Uninstalling old extension..."
cursor --uninstall-extension NguyenTruong.codepet 2>/dev/null
echo "Done."

# Step 2: Remove cached extension files from Cursor's extension directory
echo "[2/4] Clearing Cursor extension cache..."
rm -rf ~/.cursor/extensions/nguyentruong.codepet-* 2>/dev/null
rm -rf ~/.cursor/extensions/NguyenTruong.codepet-* 2>/dev/null
rm -rf "$HOME/.cursor/extensions/nguyentruong.codepet-"* 2>/dev/null
echo "Done."

# Step 3: Build fresh from source
echo "[3/4] Building extension from source..."
cd "$(dirname "$0")"
npx tsc 2>&1
npx @vscode/vsce package --no-dependencies -o codepet-fresh.vsix 2>&1 | tail -3
echo "Done."

# Step 4: Install the fresh build
echo "[4/4] Installing fresh extension..."
cursor --install-extension ./codepet-fresh.vsix
echo ""
echo "=== DONE ==="
echo "Now FULLY QUIT Cursor (Cmd+Q) and reopen it."
echo "You should see a purple welcome banner at the top of the Codepet sidebar."
