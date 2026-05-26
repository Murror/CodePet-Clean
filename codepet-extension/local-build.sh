#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Codepet Extension — LOCAL Build & Install
# Run this DIRECTLY in your Terminal (NOT through Cowork sandbox)
# ═══════════════════════════════════════════════════════════════

set -e
echo ""
echo "═══════════════════════════════════════════════"
echo "  Codepet Extension — Local Build & Install"
echo "═══════════════════════════════════════════════"
echo ""

# Navigate to the extension folder
cd "$(dirname "$0")"
echo "📁 Working directory: $(pwd)"
echo ""

# Step 1: Uninstall ALL old versions
echo "🗑  [1/6] Uninstalling old extension..."
cursor --uninstall-extension NguyenTruong.codepet 2>/dev/null || true
echo "   Done."

# Step 2: Nuke cached extensions
echo "🧹 [2/6] Clearing ALL extension caches..."
rm -rf ~/.cursor/extensions/nguyentruong.codepet-* 2>/dev/null || true
rm -rf ~/.cursor/extensions/NguyenTruong.codepet-* 2>/dev/null || true
# Also clear the CachedExtensionVSIXs folder
rm -rf ~/Library/Application\ Support/Cursor/CachedExtensionVSIXs/nguyentruong.codepet-* 2>/dev/null || true
rm -rf ~/Library/Application\ Support/Cursor/CachedExtensionVSIXs/NguyenTruong.codepet-* 2>/dev/null || true
echo "   Done."

# Step 3: DELETE the old dist/ folder completely
echo "🔥 [3/6] Deleting old dist/ folder..."
rm -rf dist/
echo "   Done. dist/ is gone."

# Step 4: Rebuild from source
echo "🔨 [4/6] Compiling TypeScript from source..."
npx tsc
echo "   Done. New dist/ created."

# Step 5: Verify the new build has our changes
echo "🔍 [5/6] Verifying build..."
if grep -q "plutil" dist/services/cloud-sync.js 2>/dev/null; then
  echo "   ✅ New plist reader (plutil) present — GOOD!"
else
  echo "   ⚠️  plutil code NOT found — old build may be cached"
fi

if grep -q "welcome-banner" dist/ui/sidebar-provider.js 2>/dev/null; then
  echo "   ✅ Welcome banner code present — GOOD!"
else
  echo "   ❌ Welcome banner code NOT found in dist!"
  exit 1
fi

if grep -q "isCloudLinked" dist/ui/sidebar-provider.js 2>/dev/null; then
  echo "   ✅ Cloud link status present — GOOD!"
else
  echo "   ⚠️  isCloudLinked NOT found — may be stale"
fi

# Step 6: Package and install
echo "📦 [6/6] Packaging & installing..."
rm -f codepet-local.vsix 2>/dev/null || true
npx @vscode/vsce package --no-dependencies -o codepet-local.vsix 2>&1 | tail -5
cursor --install-extension ./codepet-local.vsix
echo ""
echo "═══════════════════════════════════════════════"
echo "  ✅ DONE!"
echo ""
echo "  Now FULLY QUIT Cursor: Cmd + Q"
echo "  Then reopen Cursor."
echo ""
echo "  You should see:"
echo "  🟣 Purple welcome banner at the top of Codepet sidebar"
echo "  🔴 Debug Log section at the bottom"
echo "  📝 Activity feed says 'v0.9.1'"
echo "═══════════════════════════════════════════════"
echo ""
