#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Codepet — Full Rebuild & Auto-Test
# Run this ONCE in Terminal. It rebuilds everything and tests.
# ═══════════════════════════════════════════════════════════════

set -e
cd "$(dirname "$0")"

echo ""
echo "═══════════════════════════════════════════════"
echo "  Step 1/4: Building Cursor Extension"
echo "═══════════════════════════════════════════════"

# Uninstall old
cursor --uninstall-extension NguyenTruong.codepet 2>/dev/null || true

# Clear caches
rm -rf ~/.cursor/extensions/nguyentruong.codepet-* 2>/dev/null || true
rm -rf ~/.cursor/extensions/NguyenTruong.codepet-* 2>/dev/null || true
rm -rf ~/Library/Application\ Support/Cursor/CachedExtensionVSIXs/nguyentruong.codepet-* 2>/dev/null || true

# Build
rm -rf dist/
npx tsc
echo "  ✅ TypeScript compiled"

# Verify key changes
PASS=true
if grep -q "plutil" dist/services/cloud-sync.js 2>/dev/null; then
  echo "  ✅ Plist reader (plutil) present"
else
  echo "  ❌ Missing plutil code"; PASS=false
fi
if grep -q "seedFromCloud" dist/core/session-tracker.js 2>/dev/null; then
  echo "  ✅ Session seeding present"
else
  echo "  ❌ Missing seedFromCloud"; PASS=false
fi
if grep -q "isCloudLinked" dist/ui/sidebar-provider.js 2>/dev/null; then
  echo "  ✅ Cloud link status present"
else
  echo "  ❌ Missing isCloudLinked"; PASS=false
fi
if grep -q "hasMCP" dist/ui/sidebar-provider.js 2>/dev/null; then
  echo "  ✅ MCP fallback display present"
else
  echo "  ❌ Missing MCP fallback"; PASS=false
fi
if grep -q "resolvedPetName" dist/ui/status-bar.js 2>/dev/null; then
  echo "  ✅ Status bar pet name fix present"
else
  echo "  ❌ Missing status bar fix"; PASS=false
fi

if [ "$PASS" = false ]; then
  echo ""
  echo "  ⚠️  Some checks failed — the source files may not have the latest changes."
  echo "  Continuing anyway..."
fi

# Package & install
rm -f codepet-local.vsix 2>/dev/null || true
npx @vscode/vsce package --no-dependencies -o codepet-local.vsix 2>&1 | tail -3
cursor --install-extension ./codepet-local.vsix
echo "  ✅ Extension installed"

echo ""
echo "═══════════════════════════════════════════════"
echo "  Step 2/4: Building macOS App"
echo "═══════════════════════════════════════════════"

cd ..
if [ -f "codepet.xcodeproj/project.pbxproj" ]; then
  echo "  Building with xcodebuild..."
  xcodebuild -project codepet.xcodeproj -scheme codepet -configuration Debug build 2>&1 | tail -5
  echo "  ✅ macOS app built"
else
  echo "  ⚠️  codepet.xcodeproj not found — skip (rebuild manually in Xcode with ⌘R)"
fi

echo ""
echo "═══════════════════════════════════════════════"
echo "  Step 3/4: Verifying Data Pipeline"
echo "═══════════════════════════════════════════════"

# Check if macOS app has a signed-in user
UID_VAL=$(defaults read app.murror.codepet cp_currentUserId 2>/dev/null || echo "")
if [ -n "$UID_VAL" ]; then
  echo "  ✅ macOS app user ID: ${UID_VAL:0:8}..."
else
  echo "  ❌ No user ID found — is the macOS app signed in?"
fi

# Check active character
CHAR=$(defaults read app.murror.codepet cp_activeChar 2>/dev/null || echo "")
if [ -n "$CHAR" ]; then
  echo "  ✅ Active character: $CHAR"
else
  echo "  ⚠️  No active character found"
fi

# Check MCP summary files
SUMMARY_DIR="$HOME/.codepet/summaries"
if [ -d "$SUMMARY_DIR" ]; then
  LATEST=$(ls -t "$SUMMARY_DIR"/*.json 2>/dev/null | head -1)
  if [ -n "$LATEST" ]; then
    echo "  ✅ Latest MCP summary: $(basename "$LATEST")"
    # Show key stats from the summary
    python3 -c "
import json, sys
with open('$LATEST') as f:
    d = json.load(f)
print(f'     → {d.get(\"totalCodingMinutes\",0)}m coding, +{d.get(\"linesAdded\",0)} lines, {d.get(\"commits\",0)} commits')
" 2>/dev/null || echo "     (could not parse summary)"
  else
    echo "  ⚠️  No summary files found"
  fi
else
  echo "  ⚠️  ~/.codepet/summaries/ does not exist (MCP server not running)"
fi

echo ""
echo "═══════════════════════════════════════════════"
echo "  Step 4/4: Done!"
echo "═══════════════════════════════════════════════"
echo ""
echo "  Now do this:"
echo ""
echo "  1. FULLY QUIT Cursor → Cmd + Q"
echo "  2. Reopen Cursor"
echo "  3. Open any file and TYPE a few characters"
echo "  4. Wait 60 seconds"
echo "  5. Check: sidebar should show coding time"
echo "  6. Check: macOS app dashboard should match"
echo ""
echo "  If the sidebar shows 'Synced with macOS App'"
echo "  and the status bar shows 'Byte', it's working!"
echo ""
