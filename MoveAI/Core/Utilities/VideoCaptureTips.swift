//
//  VideoCaptureTips.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import Foundation

/// Centralized tips for video capture and analysis troubleshooting
enum VideoCaptureTips {

    // MARK: - Tips for Specific Error Scenarios

    static let tipsForNoPoseData: [String] = [
        "Ensure pose detection was enabled during recording",
        "Check that your full body is visible in the frame",
        "Try recording again with better lighting"
    ]

    static let tipsForInsufficientFrames: [String] = [
        "Record for at least 3-5 seconds",
        "Ensure continuous movement throughout the recording",
        "Avoid pausing mid-movement",
        "Complete the full movement from start to finish"
    ]

    static let tipsForMissingKeypoints: [String] = [
        "Ensure your full body is visible from head to feet",
        "Position camera at side angle (45-90 degrees) for best detection",
        "Wear contrasting clothing to improve detection",
        "Ensure good lighting on your body",
        "Keep your entire body within the frame throughout the movement"
    ]

    static let tipsForLowConfidence: [String] = [
        "Improve lighting conditions - ensure even, bright lighting",
        "Move closer to camera or adjust zoom",
        "Ensure clear background contrast",
        "Avoid fast, jerky movements during recording",
        "Wear clothing that contrasts with the background",
        "Ensure camera lens is clean"
    ]

    static let tipsForNoMovement: [String] = [
        "Ensure you perform the complete movement",
        "Record the full range of motion",
        "Avoid staying in one position for too long",
        "Make sure the movement is clearly visible"
    ]

    static let tipsForCameraAngle: [String] = [
        "Position camera at 45-90 degree angle to your side",
        "Keep camera at hip-to-shoulder height",
        "Ensure full body is visible from head to feet",
        "Avoid extreme angles (too high or too low)",
        "Keep camera steady during recording"
    ]

    static let tipsForVideoProcessing: [String] = [
        "Ensure video is in MP4 or MOV format",
        "Video should be under 2 minutes for best performance",
        "Ensure video shows complete movement from start to finish",
        "Check that video file is not corrupted",
        "Try with a shorter video if processing takes too long"
    ]

    // MARK: - General Best Practices

    static let generalTips: [String] = [
        "Position camera at side angle (45-90 degrees)",
        "Ensure good, even lighting",
        "Keep full body visible in frame",
        "Record for at least 3-5 seconds",
        "Perform complete movement from start to finish",
        "Wear contrasting clothing",
        "Ensure clear background"
    ]

    // MARK: - Movement-Specific Tips

    static func tipsForMovement(_ movementType: MovementType) -> [String] {
        switch movementType {
        case .squat:
            return squatTips
        case .deadlift:
            return deadliftTips
        case .benchPress:
            return benchPressTips
        case .muayThai:
            return muayThaiTips
        }
    }

    private static let squatTips: [String] = [
        "Position camera to your side at hip height",
        "Ensure knees, hips, and shoulders are clearly visible",
        "Record the full squat from standing to bottom position",
        "Keep your entire body in frame throughout the movement"
    ]

    private static let deadliftTips: [String] = [
        "Position camera to your side",
        "Ensure full body is visible from feet to head",
        "Record the complete lift from floor to standing position"
    ]

    private static let benchPressTips: [String] = [
        "Position camera to your side or at an angle",
        "Ensure shoulders, elbows, and wrists are visible",
        "Record the full range of motion"
    ]

    private static let muayThaiTips: [String] = [
        "Keep your full body in frame with enough space to complete strikes",
        "Use a stable camera at waist-to-chest height",
        "Record one technique per clip for cleaner analysis",
        "For punches and elbows, front or slight diagonal works best",
        "For kicks and knees, keep both hips and both ankles clearly visible"
    ]
}
