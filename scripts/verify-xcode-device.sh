#!/bin/bash

# verify-xcode-device.sh
# Verifies Xcode and iOS device compatibility
# Checks Xcode version, iOS version, and device connection status

set -e

echo "🔍 Xcode and Device Compatibility Check"
echo "======================================="
echo ""

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Xcode command line tools not found"
    exit 1
fi

# Get Xcode version
XCODE_VERSION=$(xcodebuild -version | head -n 1 | awk '{print $2}')
XCODE_BUILD=$(xcodebuild -version | tail -n 1 | awk '{print $3}')

echo "📱 Xcode Information:"
echo "   Version: $XCODE_VERSION"
echo "   Build: $XCODE_BUILD"
echo ""

# Check Xcode path
XCODE_PATH=$(xcode-select -p 2>/dev/null || echo "Not set")
echo "   Path: $XCODE_PATH"
echo ""

# Get iOS SDK version
IOS_SDK=$(xcodebuild -showsdks | grep -i "iphoneos" | head -n 1 | awk '{print $NF}' || echo "Not found")
echo "📦 iOS SDK:"
echo "   Version: $IOS_SDK"
echo ""

# Check for connected devices
echo "📱 Connected Devices:"
DEVICES=$(xcrun simctl list devices 2>/dev/null | grep -i "iphone" | grep -v "unavailable" | head -n 5 || echo "  No simulators found")

if [ -n "$DEVICES" ] && [ "$DEVICES" != "  No simulators found" ]; then
    echo "$DEVICES"
else
    echo "  No iOS simulators found"
fi

echo ""

# Check for physical devices via instruments (if available)
if command -v instruments &> /dev/null; then
    echo "🔌 Physical Devices:"
    PHYSICAL_DEVICES=$(instruments -s devices 2>/dev/null | grep -i "iphone" | grep -v "Simulator" || echo "  No physical devices found")
    echo "$PHYSICAL_DEVICES"
    echo ""
fi

# Check device support directory
DEVICE_SUPPORT="$HOME/Library/Developer/Xcode/iOS DeviceSupport"
if [ -d "$DEVICE_SUPPORT" ]; then
    DEVICE_COUNT=$(find "$DEVICE_SUPPORT" -maxdepth 1 -type d | wc -l | tr -d ' ')
    DEVICE_COUNT=$((DEVICE_COUNT - 1))  # Subtract 1 for the directory itself
    
    echo "💾 Device Support Files:"
    echo "   Count: $DEVICE_COUNT device(s)"
    
    if [ $DEVICE_COUNT -gt 0 ]; then
        echo "   Devices:"
        for device_dir in "$DEVICE_SUPPORT"/*; do
            if [ -d "$device_dir" ]; then
                SIZE=$(du -sh "$device_dir" 2>/dev/null | cut -f1 || echo "unknown")
                echo "     - $(basename "$device_dir") ($SIZE)"
            fi
        done
    fi
    echo ""
fi

# Compatibility check
echo "✅ Compatibility Status:"
XCODE_MAJOR=$(echo "$XCODE_VERSION" | cut -d. -f1)
XCODE_MINOR=$(echo "$XCODE_VERSION" | cut -d. -f2)

# Basic compatibility check (Xcode 16.x should support iOS 18.x)
if [ "$XCODE_MAJOR" -ge 16 ]; then
    echo "   ✅ Xcode version is compatible with iOS 18.x"
else
    echo "   ⚠️  Xcode version may not fully support iOS 18.x"
    echo "      Consider updating to Xcode 16.x or later"
fi

echo ""
echo "💡 Tips:"
echo "   - If symbol copying is stuck, try running:"
echo "     ./scripts/clean-xcode-device-support.sh \"Dave's iphone\""
echo "   - For comprehensive cleanup, run:"
echo "     ./scripts/clean-xcode-caches.sh"
echo ""
