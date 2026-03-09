import Foundation

enum MovementCueCatalog {
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
        if let squat = SquatCueLibrary.entry(for: kind) {
            return convert(squat)
        }
        if let muayThai = MuayThaiCueLibrary.entry(for: kind) {
            return convert(muayThai)
        }
        return nil
    }

    private static func convert(_ entry: SquatCueLibrary.Entry) -> Entry {
        let drills = dedupe(
            entry.correctives.mobility + entry.correctives.patterning + entry.correctives.strength
        )

        return Entry(
            kind: entry.kind,
            name: entry.name,
            headline: entry.headline,
            oneLineDescription: entry.oneLineDescription,
            quickFix: entry.quickFix,
            quickFixRationale: entry.quickFixRationale,
            backupCues: entry.backupCues,
            recommendedDrills: drills,
            phaseSummaryText: phaseSummary(for: entry.commonPhases)
        )
    }

    private static func convert(_ entry: MuayThaiCueLibrary.Entry) -> Entry {
        Entry(
            kind: entry.kind,
            name: entry.name,
            headline: entry.headline,
            oneLineDescription: entry.oneLineDescription,
            quickFix: entry.quickFix,
            quickFixRationale: entry.quickFixRationale,
            backupCues: entry.backupCues,
            recommendedDrills: dedupe(entry.recommendedDrills),
            phaseSummaryText: entry.phaseSummaryText
        )
    }

    private static func dedupe(_ items: [String]) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []

        for item in items {
            let cleaned = item.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { continue }
            guard !seen.contains(cleaned.lowercased()) else { continue }
            seen.insert(cleaned.lowercased())
            ordered.append(cleaned)
        }

        return ordered
    }

    private static func phaseSummary(for phases: Set<SquatPhaseType>) -> String {
        guard !phases.isEmpty else {
            return "Varies by rep and fatigue."
        }

        let ordered: [SquatPhaseType] = [.setup, .descent, .bottom, .ascent]
        let labels = ordered.filter { phases.contains($0) }.map { $0.rawValue.capitalized }
        if labels.isEmpty {
            return "Varies by rep and fatigue."
        }
        return labels.joined(separator: " + ")
    }
}
