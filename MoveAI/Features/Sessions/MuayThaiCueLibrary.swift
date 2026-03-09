import Foundation

enum MuayThaiCueLibrary {
    struct Entry {
        let kind: MovementIssueKind
        let name: String
        let headline: String
        let oneLineDescription: String
        let poseHints: [String]
        let quickFix: String
        let quickFixRationale: String?
        let backupCues: [String]
        let recommendedDrills: [String]
        let phaseSummaryText: String
        let overlayTargets: [BodyJoint]
    }

    static func entry(for kind: MovementIssueKind) -> Entry? {
        if kind == .muayThaiAnalysisCoverageLimited {
            return Entry(
                kind: kind,
                name: "analysis coverage limited",
                headline: "Analysis coverage limited",
                oneLineDescription: "Some Muay Thai checks were skipped because required keypoint signals are unavailable.",
                poseHints: [],
                quickFix: "Record clear full-body footage and focus on currently supported checks.",
                quickFixRationale: "Additional pose-model signals are required for blocked checks.",
                backupCues: ["Capture full body", "Use stable camera angle"],
                recommendedDrills: [],
                phaseSummaryText: "Set-level",
                overlayTargets: []
            )
        }

        guard let catalogEntry = MuayThaiIssueCatalog.entry(for: kind) else { return nil }

        let fallbackHeadline = kind.rawValue
            .split(separator: ".")
            .last
            .map { $0.replacingOccurrences(of: "_", with: " ") }
            .map { $0.split(separator: " ").map { $0.capitalized }.joined(separator: " ") }
            ?? "Technique Issue"

        return Entry(
            kind: kind,
            name: catalogEntry.issueKind.rawValue,
            headline: fallbackHeadline,
            oneLineDescription: catalogEntry.description,
            poseHints: catalogEntry.poseDetectionHints,
            quickFix: catalogEntry.cueShort,
            quickFixRationale: catalogEntry.cueDetailed,
            backupCues: [catalogEntry.cueDetailed],
            recommendedDrills: catalogEntry.recommendedDrills,
            phaseSummaryText: catalogEntry.phase.capitalized,
            overlayTargets: []
        )
    }
}
