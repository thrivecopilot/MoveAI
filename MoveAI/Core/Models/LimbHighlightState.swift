import Foundation

/// Severity level for highlighted limbs on the pose overlay.
enum HighlightSeverity: Comparable {
    case warning // Yellow/amber - needs improvement
    case critical // Red - danger/critical issue
}

/// Maps body joints to their highlight severity for the current frame.
/// Empty dictionary = no highlights (confidence-based fallback).
typealias LimbHighlightState = [BodyJoint: HighlightSeverity]
