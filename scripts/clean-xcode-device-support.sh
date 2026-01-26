#!/bin/bash

# clean-xcode-device-support.sh
# Cleans Xcode device support files to resolve symbol copying issues
# Usage: ./scripts/clean-xcode-device-support.sh [device-name]

set -e

DEVICE_SUPPORT_DIR="$HOME/Library/Developer/Xcode/iOS DeviceSupport"
DEVICE_NAME="${1:-}"

echo "🧹 Xcode Device Support Cleanup"
echo "================================"
echo ""

# Check if device support directory exists
if [ ! -d "$DEVICE_SUPPORT_DIR" ]; then
    echo "❌ Device support directory not found: $DEVICE_SUPPORT_DIR"
    exit 1
fi

# List current device support folders
echo "📱 Current device support folders:"
ls -lh "$DEVICE_SUPPORT_DIR" | tail -n +2 | awk '{print "  - " $9 " (" $5 ")"}'
echo ""

# If device name is provided, clean only that device
if [ -n "$DEVICE_NAME" ]; then
    echo "🎯 Cleaning device support for: $DEVICE_NAME"
    
    # Find and remove matching device folders
    FOUND=0
    for folder in "$DEVICE_SUPPORT_DIR"/*; do
        if [ -d "$folder" ] && [[ "$(basename "$folder")" == *"$DEVICE_NAME"* ]]; then
            echo "  Removing: $(basename "$folder")"
            rm -rf "$folder"
            FOUND=1
        fi
    done
    
    if [ $FOUND -eq 0 ]; then
        echo "  ⚠️  No device support folders found matching: $DEVICE_NAME"
    else
        echo "  ✅ Device support cleaned for: $DEVICE_NAME"
    fi
else
    # Ask for confirmation before cleaning all
    echo "⚠️  WARNING: This will remove ALL device support files."
    echo "   Xcode will need to re-download symbols on next device connection."
    echo ""
    read -p "Continue? (y/N): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🗑️  Removing all device support files..."
        rm -rf "$DEVICE_SUPPORT_DIR"/*
        echo "  ✅ All device support files removed"
    else
        echo "  ❌ Cancelled"
        exit 0
    fi
fi

echo ""
echo "✅ Cleanup complete!"
echo ""
echo "💡 Next steps:"
echo "   1. Quit Xcode completely"
echo "   2. Reconnect your device"
echo "   3. Open Xcode and let it re-download symbols"
echo ""
