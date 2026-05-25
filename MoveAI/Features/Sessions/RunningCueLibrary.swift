import Foundation

enum RunningCueLibrary {
    struct Entry {
        let kind: MovementIssueKind
        let name: String
        let headline: String
        let oneLineDescription: String
        let quickFix: String
        let quickFixRationale: String?
        let backupCues: [String]
        let recommendedDrills: [String]
        let phaseSummaryText: String
    }

    static func entry(for kind: MovementIssueKind) -> Entry? {
        switch kind {
        case .runningLowCadence:
            return Entry(
                kind: kind,
                name: "low cadence",
                headline: "Cadence is low",
                oneLineDescription: "Step turnover is lower than target, which can increase braking and loading per step.",
                quickFix: "Increase cadence by 3-5% while keeping stride relaxed.",
                quickFixRationale: "Small cadence increases usually reduce overstriding without forcing speed changes.",
                backupCues: ["Quick light steps", "Land under your center of mass"],
                recommendedDrills: ["Metronome strides", "Cadence pickup intervals"],
                phaseSummaryText: "Set-level"
            )
        case .runningExcessiveForwardLean:
            return Entry(
                kind: kind,
                name: "forward lean",
                headline: "Torso leaned too far forward",
                oneLineDescription: "Forward trunk angle drifted beyond target during stance, reducing postural efficiency.",
                quickFix: "Run tall with slight lean from ankles, not the waist.",
                quickFixRationale: "Ankle-led lean preserves posture while keeping force direction efficient.",
                backupCues: ["Tall posture", "Ribs stacked over pelvis"],
                recommendedDrills: ["Wall lean march", "A-skip posture drill"],
                phaseSummaryText: "Mid-stance"
            )
        case .runningExcessiveVerticalOscillation:
            return Entry(
                kind: kind,
                name: "vertical oscillation",
                headline: "Too much bounce",
                oneLineDescription: "Vertical motion is high relative to stride progression, wasting energy each step.",
                quickFix: "Keep hips level and push back, not up.",
                quickFixRationale: "Reducing bounce improves efficiency and pace sustainability.",
                backupCues: ["Glide forward", "Quiet upper body"],
                recommendedDrills: ["Fast-feet strides", "Low-bounce treadmill pickups"],
                phaseSummaryText: "Set-level"
            )
        case .runningAsymmetricStride:
            return Entry(
                kind: kind,
                name: "stride asymmetry",
                headline: "Stride is asymmetric",
                oneLineDescription: "Left/right stride pattern is uneven, which can increase inefficiency and local overload.",
                quickFix: "Ease pace and match left/right rhythm before building speed.",
                quickFixRationale: "Symmetry first keeps loading more balanced as intensity increases.",
                backupCues: ["Equal push both sides", "Balanced rhythm"],
                recommendedDrills: ["Single-leg hops", "March-skip symmetry drill"],
                phaseSummaryText: "Set-level"
            )
        case .runningOverstriding:
            return Entry(
                kind: kind,
                name: "overstriding",
                headline: "Overstriding detected",
                oneLineDescription: "Foot strike lands too far ahead of the hips, increasing braking on contact.",
                quickFix: "Shorten stride slightly and keep foot strike under hips.",
                quickFixRationale: "Landing closer to center of mass reduces braking impulse.",
                backupCues: ["Foot under hips", "Quick compact stride"],
                recommendedDrills: ["Downhill strides (gentle grade)", "Cadence-focused intervals"],
                phaseSummaryText: "Initial contact"
            )
        case .runningCaptureQualityLimited:
            return Entry(
                kind: kind,
                name: "capture quality limited",
                headline: "Capture quality limited",
                oneLineDescription: "Video quality or framing reduced running-analysis reliability.",
                quickFix: "Refilm with full body in frame, stable camera, and stronger lighting.",
                quickFixRationale: "Reliable keypoint tracking is required for running-metrics confidence.",
                backupCues: ["Keep full body visible", "Use stable side-angle capture"],
                recommendedDrills: [],
                phaseSummaryText: "Set-level"
            )
        default:
            return nil
        }
    }
}
