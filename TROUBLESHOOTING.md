# Xcode Troubleshooting Guide

This guide covers common Xcode issues and their solutions, with a focus on symbol copying problems.

## Table of Contents

- [Symbol Copying Issues](#symbol-copying-issues)
- [Device Connection Problems](#device-connection-problems)
- [Build and Cache Issues](#build-and-cache-issues)
- [Quick Fix Scripts](#quick-fix-scripts)
- [Prevention Tips](#prevention-tips)

## Symbol Copying Issues

### Problem: Xcode Stuck on "Copying shared cache symbols"

**Symptoms:**
- Xcode hangs at "Copying shared cache symbols from [Device Name] (1% completed)"
- Process never completes, even after waiting
- Device appears connected but Xcode can't finish symbol setup

**Root Causes:**
1. **Corrupted Device Support Files**: Device support files in `~/Library/Developer/Xcode/iOS DeviceSupport` may be corrupted or incomplete
2. **Version Mismatch**: Xcode version may not fully support the iOS version on your device
3. **Cache Corruption**: Xcode's derived data or module cache may be corrupted
4. **Network Issues**: Slow or interrupted connection during initial symbol download
5. **Storage Issues**: Insufficient disk space on Mac or device

### Solution Steps

#### Step 1: Quick Fix - Clean Device Support Files

The fastest solution is to remove the device support files for your specific device:

```bash
./scripts/clean-xcode-device-support.sh "Dave's iphone"
```

This will:
- Remove corrupted device support files
- Force Xcode to re-download symbols on next connection
- Preserve other device support files

**After running:**
1. Quit Xcode completely (⌘Q)
2. Disconnect and reconnect your iPhone
3. Open Xcode and wait for symbol download to complete

#### Step 2: Comprehensive Cache Cleanup

If Step 1 doesn't work, perform a comprehensive cleanup:

```bash
./scripts/clean-xcode-caches.sh
```

This will clean:
- Derived Data (build artifacts)
- Module Cache
- Archives (optional)
- Device Support files (optional)

**Warning**: This will require Xcode to rebuild all caches, which may take time on first build.

#### Step 3: Manual Cleanup (If Scripts Don't Work)

If you prefer manual cleanup:

1. **Quit Xcode completely**
2. **Remove device support files**:
   ```bash
   rm -rf ~/Library/Developer/Xcode/iOS\ DeviceSupport/*
   ```
3. **Clear derived data** (optional but recommended):
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/*
   ```
4. **Restart your Mac** (helps clear any stuck processes)
5. **Reconnect device and open Xcode**

#### Step 4: Verify Compatibility

Check if your Xcode and iOS versions are compatible:

```bash
./scripts/verify-xcode-device.sh
```

This will show:
- Xcode version and build number
- iOS SDK version
- Connected devices
- Device support file status

### Alternative Workarounds

#### Workaround 1: Use Simulator Temporarily

While fixing device issues, you can continue development using the iOS Simulator:
- Simulators don't require symbol copying
- Faster iteration for UI development
- Test device-specific features later

#### Workaround 2: Disable Symbol Copying (Not Recommended)

You can disable automatic symbol copying, but this will impact debugging:
1. Xcode → Preferences → Components
2. Uncheck "Automatically download symbols"
3. **Note**: This will make debugging crashes more difficult

## Device Connection Problems

### Problem: Device Not Recognized

**Symptoms:**
- Device doesn't appear in Xcode's device list
- "Device not trusted" errors
- Connection drops frequently

**Solutions:**

1. **Trust the Computer on Device**:
   - Unlock your iPhone
   - When prompted, tap "Trust This Computer"
   - Enter your passcode

2. **Check USB Connection**:
   - Try a different USB cable
   - Try a different USB port
   - Use a direct connection (avoid hubs)

3. **Restart Services**:
   ```bash
   # Kill and restart usbmuxd
   sudo killall usbmuxd
   # It will restart automatically
   ```

4. **Reset Location & Privacy**:
   - On iPhone: Settings → General → Transfer or Reset iPhone → Reset → Reset Location & Privacy
   - Re-trust the computer after reset

### Problem: "Device is Busy" Error

**Solutions:**

1. **Close Other Apps Using Device**:
   - Close iTunes/Music if open
   - Close Finder windows showing device
   - Close other Xcode windows

2. **Restart Device**:
   - Power off and on your iPhone
   - Reconnect to Mac

3. **Restart Xcode**:
   - Quit Xcode completely
   - Reopen and reconnect device

## Build and Cache Issues

### Problem: Slow Builds

**Solutions:**

1. **Clean Derived Data**:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/*
   ```

2. **Enable Build Parallelization**:
   - Xcode → Preferences → Locations
   - Increase "Derived Data" location if needed
   - Ensure "Build System" is set to "New Build System"

3. **Check Build Settings**:
   - Ensure `ONLY_ACTIVE_ARCH = YES` for Debug builds
   - Use `DEBUG_INFORMATION_FORMAT = dwarf` for Debug (faster)
   - Use `dwarf-with-dsym` only for Release builds

### Problem: "Module Not Found" Errors

**Solutions:**

1. **Clean Module Cache**:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/*
   ```

2. **Reset Package Dependencies**:
   - File → Packages → Reset Package Caches
   - File → Packages → Update to Latest Package Versions

3. **Clean Build Folder**:
   - Product → Clean Build Folder (⇧⌘K)

## Quick Fix Scripts

This project includes several scripts to automate common fixes:

### `scripts/clean-xcode-device-support.sh`

Cleans device support files for a specific device or all devices.

**Usage:**
```bash
# Clean specific device
./scripts/clean-xcode-device-support.sh "Dave's iphone"

# Clean all devices (with confirmation)
./scripts/clean-xcode-device-support.sh
```

### `scripts/clean-xcode-caches.sh`

Comprehensive cache cleanup with interactive prompts.

**Usage:**
```bash
./scripts/clean-xcode-caches.sh
```

Follow the prompts to selectively clean:
- Derived Data
- Archives
- Device Support
- Module Cache

### `scripts/verify-xcode-device.sh`

Verifies Xcode installation and device compatibility.

**Usage:**
```bash
./scripts/verify-xcode-device.sh
```

Shows:
- Xcode version and build
- iOS SDK version
- Connected devices
- Device support file status

## Prevention Tips

### Regular Maintenance

1. **Monthly Cleanup**:
   - Run `clean-xcode-caches.sh` monthly
   - Remove old archives you no longer need
   - Clean device support for devices you no longer use

2. **Monitor Disk Space**:
   - Xcode caches can grow to 10GB+ easily
   - Keep at least 20GB free for Xcode operations
   - Use `verify-xcode-device.sh` to check cache sizes

3. **Keep Xcode Updated**:
   - Update Xcode regularly for bug fixes
   - Match Xcode version with your primary iOS target version
   - Check release notes for known issues

### Best Practices

1. **Device Management**:
   - Only connect devices you're actively developing for
   - Disconnect devices when not in use
   - Trust computers only on secure networks

2. **Build Settings**:
   - Use appropriate debug information formats
   - Enable `ONLY_ACTIVE_ARCH` for Debug builds
   - Use Release configuration for performance testing

3. **Project Organization**:
   - Keep project files organized
   - Avoid very deep directory structures
   - Use relative paths where possible

## Getting Help

If issues persist after trying these solutions:

1. **Check Xcode Release Notes**:
   - Look for known issues in your Xcode version
   - Check for workarounds or fixes

2. **Apple Developer Forums**:
   - Search for similar issues
   - Post with specific error messages and versions

3. **System Information**:
   - Run `verify-xcode-device.sh` and include output
   - Note macOS version, Xcode version, iOS version
   - Include any error messages from Console.app

4. **Reset Xcode Preferences** (Last Resort):
   ```bash
   # Backup first!
   cp ~/Library/Preferences/com.apple.dt.Xcode.plist ~/Desktop/
   # Then remove
   rm ~/Library/Preferences/com.apple.dt.Xcode.plist
   ```

## Related Files

- [MoveAI.xcodeproj/project.pbxproj](MoveAI.xcodeproj/project.pbxproj) - Project build settings
- [scripts/clean-xcode-device-support.sh](scripts/clean-xcode-device-support.sh) - Device support cleanup
- [scripts/clean-xcode-caches.sh](scripts/clean-xcode-caches.sh) - Cache cleanup
- [scripts/verify-xcode-device.sh](scripts/verify-xcode-device.sh) - Compatibility verification

---

**Last Updated**: 2024
**Maintained By**: MoveAI Development Team
