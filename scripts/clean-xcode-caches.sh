#!/bin/bash

# clean-xcode-caches.sh
# Comprehensive Xcode cache cleanup script
# Cleans derived data, archives, device support, and module cache

set -e

echo "🧹 Xcode Comprehensive Cache Cleanup"
echo "====================================="
echo ""

# Define cache directories
DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData"
ARCHIVES="$HOME/Library/Developer/Xcode/Archives"
DEVICE_SUPPORT="$HOME/Library/Developer/Xcode/iOS DeviceSupport"
MODULE_CACHE="$HOME/Library/Developer/Xcode/DerivedData/ModuleCache.noindex"
OLD_ARCHIVES="$HOME/Library/Developer/Xcode/Archives"

# Calculate sizes before cleanup
echo "📊 Current cache sizes:"
TOTAL_SIZE=0

if [ -d "$DERIVED_DATA" ]; then
    DERIVED_SIZE=$(du -sh "$DERIVED_DATA" 2>/dev/null | cut -f1 || echo "0")
    echo "  Derived Data: $DERIVED_SIZE"
fi

if [ -d "$ARCHIVES" ]; then
    ARCHIVES_SIZE=$(du -sh "$ARCHIVES" 2>/dev/null | cut -f1 || echo "0")
    echo "  Archives: $ARCHIVES_SIZE"
fi

if [ -d "$DEVICE_SUPPORT" ]; then
    DEVICE_SIZE=$(du -sh "$DEVICE_SUPPORT" 2>/dev/null | cut -f1 || echo "0")
    echo "  Device Support: $DEVICE_SIZE"
fi

if [ -d "$MODULE_CACHE" ]; then
    MODULE_SIZE=$(du -sh "$MODULE_CACHE" 2>/dev/null | cut -f1 || echo "0")
    echo "  Module Cache: $MODULE_SIZE"
fi

echo ""

# Ask for confirmation
echo "⚠️  WARNING: This will remove:"
echo "   - All derived data (build artifacts)"
echo "   - All archives (if you want)"
echo "   - All device support files"
echo "   - Module cache"
echo ""
read -p "Continue with cleanup? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Cancelled"
    exit 0
fi

# Clean derived data
if [ -d "$DERIVED_DATA" ]; then
    echo "🗑️  Cleaning Derived Data..."
    rm -rf "$DERIVED_DATA"/*
    echo "  ✅ Derived Data cleaned"
fi

# Clean module cache
if [ -d "$MODULE_CACHE" ]; then
    echo "🗑️  Cleaning Module Cache..."
    rm -rf "$MODULE_CACHE"/*
    echo "  ✅ Module Cache cleaned"
fi

# Ask about archives (user might want to keep them)
echo ""
read -p "Remove Archives? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]] && [ -d "$ARCHIVES" ]; then
    echo "🗑️  Cleaning Archives..."
    rm -rf "$ARCHIVES"/*
    echo "  ✅ Archives cleaned"
else
    echo "  ⏭️  Skipping Archives"
fi

# Ask about device support
echo ""
read -p "Remove Device Support files? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]] && [ -d "$DEVICE_SUPPORT" ]; then
    echo "🗑️  Cleaning Device Support..."
    rm -rf "$DEVICE_SUPPORT"/*
    echo "  ✅ Device Support cleaned"
else
    echo "  ⏭️  Skipping Device Support"
fi

echo ""
echo "✅ Cache cleanup complete!"
echo ""
echo "💡 Next steps:"
echo "   1. Quit Xcode completely"
echo "   2. Restart Xcode"
echo "   3. Reconnect your device if needed"
echo "   4. Xcode will rebuild caches on next build"
echo ""
