//
//  DeviceInfo.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/18/25.
//

import SwiftUI
import UIKit

struct DeviceInfo {
    static var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    static var isIPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }
    
    static var screenSize: CGSize {
        UIScreen.main.bounds.size
    }
    
    static var screenWidth: CGFloat {
        screenSize.width
    }
    
    static var screenHeight: CGFloat {
        screenSize.height
    }
    
    static var isLandscape: Bool {
        screenWidth > screenHeight
    }
    
    static var isPortrait: Bool {
        screenHeight > screenWidth
    }
    
    // Device-specific video sizing
    static func videoAspectRatio() -> CGFloat {
        if isIPad {
            // iPad: Use 16:9 for better viewing experience
            return 16.0 / 9.0
        } else {
            // iPhone: Use device aspect ratio for full screen
            return screenWidth / screenHeight
        }
    }
    
    static func videoContentMode() -> ContentMode {
        if isIPad {
            // iPad: Fit to maintain aspect ratio
            return .fit
        } else {
            // iPhone: Fill for immersive fullscreen experience
            return .fill
        }
    }
    
    static func videoCornerRadius() -> CGFloat {
        if isIPad {
            return 12.0
        } else {
            return 0.0 // No corner radius for fullscreen on iPhone
        }
    }
    
    // Device type for debugging
    static var deviceType: String {
        if isIPad {
            return "iPad"
        } else if isIPhone {
            return "iPhone"
        } else {
            return "Unknown"
        }
    }
    
    // Screen dimensions for debugging
    static var screenInfo: String {
        return "\(deviceType) - \(Int(screenWidth))x\(Int(screenHeight)) (\(isLandscape ? "Landscape" : "Portrait"))"
    }
}
