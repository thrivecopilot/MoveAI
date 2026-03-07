import Foundation

struct TrendsExpertResource: Identifiable, Hashable {
    let id: String
    let creator: String
    let title: String
    let issueAssociation: String
    let url: URL
    let thumbnailToken: String
    let priority: Int
    let issueKinds: Set<MovementIssueKind>
}

enum TrendsExpertCatalog {
    static let resources: [TrendsExpertResource] = {
        [
            make(
                id: "squatu-dorsiflexion",
                creator: "Squat University",
                title: "Fix Limited Ankle Dorsiflexion for Deeper Squats",
                issueAssociation: "Depth + Balance",
                url: "https://www.youtube.com/@SquatUniversity",
                thumbnailToken: "figure.strengthtraining.traditional",
                priority: 0,
                issueKinds: [.squatHeelsLift, .squatDepthTooShallow, .squatKneesStayedBack, .squatIncompleteROM]
            ),
            make(
                id: "conor-hip-shift",
                creator: "Conor Harris",
                title: "Hip Shift and Asymmetry Corrective Strategy",
                issueAssociation: "Balance + Knee Tracking",
                url: "https://www.youtube.com/@ConorHarris",
                thumbnailToken: "figure.core.training",
                priority: 1,
                issueKinds: [.squatHipShift, .squatKneeValgus, .squatFootCollapse]
            ),
            make(
                id: "kot-ankle-foot",
                creator: "Knees Over Toes",
                title: "Foot and Ankle Prep for Better Squat Mechanics",
                issueAssociation: "Foot Stability",
                url: "https://www.youtube.com/@TheKneesovertoesguy",
                thumbnailToken: "figure.run",
                priority: 1,
                issueKinds: [.squatFootCollapse, .squatHeelsLift, .squatKneeValgus]
            ),
            make(
                id: "torokhtiy-bracing",
                creator: "Torokhtiy Weightlifting",
                title: "Bracing and Torso Control During Squats",
                issueAssociation: "Torso Control",
                url: "https://www.youtube.com/@Torokhtiy",
                thumbnailToken: "rectangle.compress.vertical",
                priority: 2,
                issueKinds: [.squatForwardLean, .squatBraceLeak, .squatButtWink]
            ),
            make(
                id: "e3-depth",
                creator: "E3 Rehab",
                title: "Consistent Squat Depth: Mobility and Motor Control",
                issueAssociation: "Depth",
                url: "https://www.youtube.com/@E3Rehab",
                thumbnailToken: "figure.mixed.cardio",
                priority: 2,
                issueKinds: [.squatDepthTooShallow, .squatIncompleteROM, .squatDepthInconsistent]
            ),
            make(
                id: "juggernaut-squat-pillars",
                creator: "Juggernaut Training Systems",
                title: "Squat Technique Pillars for Strength Athletes",
                issueAssociation: "Overall Technique",
                url: "https://www.youtube.com/@JuggernautTrainingSystems",
                thumbnailToken: "dumbbell.fill",
                priority: 3,
                issueKinds: [.squatKneeValgus, .squatHeelsLift, .squatForwardLean, .squatHipShift]
            ),
        ]
        .compactMap { $0 }
    }()

    static func filtered(for issue: MovementIssueKind?, fallbackIssues: [MovementIssueKind] = []) -> [TrendsExpertResource] {
        let issueSet = Set(([issue].compactMap { $0 }) + fallbackIssues)

        let filtered: [TrendsExpertResource]
        if issueSet.isEmpty {
            filtered = resources
        } else {
            filtered = resources.filter { !$0.issueKinds.isDisjoint(with: issueSet) }
        }

        if !filtered.isEmpty {
            return filtered.sorted { lhs, rhs in
                if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
                return lhs.title < rhs.title
            }
        }

        return resources.sorted { lhs, rhs in
            if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
            return lhs.title < rhs.title
        }
    }

    private static func make(
        id: String,
        creator: String,
        title: String,
        issueAssociation: String,
        url: String,
        thumbnailToken: String,
        priority: Int,
        issueKinds: Set<MovementIssueKind>
    ) -> TrendsExpertResource? {
        guard let parsedURL = URL(string: url) else { return nil }
        return TrendsExpertResource(
            id: id,
            creator: creator,
            title: title,
            issueAssociation: issueAssociation,
            url: parsedURL,
            thumbnailToken: thumbnailToken,
            priority: priority,
            issueKinds: issueKinds
        )
    }
}
