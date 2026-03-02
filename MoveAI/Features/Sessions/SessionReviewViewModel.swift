import Foundation

@MainActor
final class SessionReviewViewModel: ObservableObject {
    @Published var currentTime: Double = 0
    @Published var currentFrameIndex: Int = 0
    @Published var isPlaying: Bool = false
    
    @Published var showSkeleton = false
    @Published var showAngles = false
    @Published var showPaths = false
    
    @Published var selectedIssueId: UUID?
    @Published var selectedOccurrenceId: UUID?
    
    @Published private(set) var issues: [IssueSummary] = []
    
    init(analysisResult: AnalysisResult?) {
        setAnalysisResult(analysisResult)
    }
    
    func setAnalysisResult(_ result: AnalysisResult?) {
        guard let result else {
            issues = []
            return
        }
        issues = IssueSummaryBuilder.from(result.feedback)
    }
    
    func updatePlayback(currentTime: Double, isPlaying: Bool, fps: Double) {
        self.currentTime = currentTime
        self.isPlaying = isPlaying
        self.currentFrameIndex = Int(round(currentTime * fps))
    }
    
    func seek(to time: Double, fps: Double) {
        currentTime = time
        currentFrameIndex = Int(round(time * fps))
    }
    
    func selectIssue(_ issue: IssueSummary) {
        selectedIssueId = issue.id
        selectedOccurrenceId = issue.worstOccurrence.id
    }
    
    func selectOccurrence(_ occurrence: IssueOccurrence, issueId: UUID) {
        selectedIssueId = issueId
        selectedOccurrenceId = occurrence.id
    }
    
    func occurrence(at time: TimeInterval, tolerance: TimeInterval) -> (issue: IssueSummary, occurrence: IssueOccurrence)? {
        for issue in issues {
            if let occ = issue.occurrences.first(where: { abs($0.time - time) <= tolerance }) {
                return (issue, occ)
            }
        }
        return nil
    }
    
    func markers() -> [ReviewMarker] {
        issues.flatMap { issue in
            issue.occurrences.map { occ in
                ReviewMarker(id: occ.id, issueId: issue.id, time: occ.time, severity: occ.severity)
            }
        }
        .sorted { $0.time < $1.time }
    }
    
    func highlightedMarkerIds() -> Set<UUID> {
        guard let selectedIssueId else { return [] }
        return Set(markers().filter { $0.issueId == selectedIssueId }.map(\.id))
    }
    
    func cueOverlay(for issue: IssueSummary) -> CoachingCueOverlay? {
        guard let cue = pickCue(for: issue) else { return nil }
        return CoachingCueOverlay(
            title: issue.title,
            severity: issue.severity,
            cue: cue,
            rationale: cue.rationale
        )
    }
    
    func cueOverlay(for issue: IssueSummary, occurrence: IssueOccurrence) -> CoachingCueOverlay? {
        guard let cue = pickCue(for: issue) else { return nil }
        return CoachingCueOverlay(
            title: issue.title,
            severity: occurrence.severity,
            cue: cue,
            rationale: cue.rationale
        )
    }
    
    private func pickCue(for issue: IssueSummary) -> CoachingCue? {
        switch issue.severity {
        case .warning, .critical:
            if let constraint = issue.cues.first(where: { $0.type == .constraint }) {
                return constraint
            }
            return issue.cues.first(where: { $0.type == .action }) ?? issue.cues.first
        case .good, .excellent:
            return nil
        }
    }
}

enum IssueSummaryBuilder {
    static func from(_ feedback: [FormFeedback]) -> [IssueSummary] {
        let grouped = Dictionary(grouping: feedback) { item in
            if let kind = MovementIssueResolver.resolve(for: item) {
                return "kind|\(kind.rawValue)"
            }
            return "legacy|\(item.category.rawValue)|\(item.message)|\(item.severity.rawValue)"
        }

        let issues = grouped.compactMap { _, items -> IssueSummary? in
            guard let first = items.first else { return nil }

            let occurrences = items.map {
                IssueOccurrence(
                    id: $0.id,
                    time: $0.timestamp,
                    severity: $0.severity,
                    affectedBodyJoints: $0.affectedBodyJoints ?? [],
                    metrics: $0.metrics ?? []
                )
            }
            .sorted { $0.time < $1.time }

            let worst = occurrences.max { a, b in
                severityOrder(a.severity) < severityOrder(b.severity)
            } ?? occurrences.first

            let worstItem = items.max { a, b in
                severityOrder(a.severity) < severityOrder(b.severity)
            }

            let issueSeverity = worstItem?.severity ?? first.severity
            let issueCategory = worstItem?.category ?? first.category
            let resolvedKind = MovementIssueResolver.resolve(for: worstItem ?? first)
            let entry = resolvedKind.flatMap { SquatCueLibrary.entry(for: $0) }

            let title: String
            let cues: [CoachingCue]

            if let entry {
                let side = sideSuffix(for: worst?.affectedBodyJoints ?? [])
                title = side.map { "\(entry.headline) \($0)" } ?? entry.headline
                cues = cuesFromEntry(entry, severity: issueSeverity)
            } else {
                title = first.message
                cues = legacyCues(for: first, severity: issueSeverity)
            }

            return IssueSummary(
                id: first.id,
                title: title,
                category: issueCategory,
                severity: issueSeverity,
                occurrences: occurrences,
                worstOccurrence: worst ?? occurrences.first!,
                worstValue: nil,
                cues: cues
            )
        }

        return issues.sorted { severityOrder($0.severity) > severityOrder($1.severity) }
    }

    private static func legacyCues(for feedback: FormFeedback, severity: FeedbackSeverity) -> [CoachingCue] {
        switch severity {
        case .warning, .critical:
            return [CoachingCue(type: .constraint, shortText: feedback.message)]
        case .good, .excellent:
            return []
        }
    }

    private static func cuesFromEntry(_ entry: SquatCueLibrary.Entry, severity: FeedbackSeverity) -> [CoachingCue] {
        switch severity {
        case .warning, .critical:
            var cues: [CoachingCue] = []
            cues.append(CoachingCue(type: .constraint, shortText: entry.quickFix, rationale: entry.quickFixRationale))
            cues.append(contentsOf: entry.backupCues.map { CoachingCue(type: .action, shortText: $0) })
            return cues
        case .good, .excellent:
            return []
        }
    }

    private static func sideSuffix(for joints: [BodyJoint]) -> String? {
        guard !joints.isEmpty else { return nil }
        let allLeft = joints.allSatisfy { $0.isLeftSide }
        let allRight = joints.allSatisfy { $0.isRightSide }
        if allLeft { return "(Left)" }
        if allRight { return "(Right)" }
        return nil
    }

    private static func severityOrder(_ s: FeedbackSeverity) -> Int {
        switch s {
        case .critical: return 4
        case .warning:  return 3
        case .good:     return 2
        case .excellent: return 1
        }
    }
}

enum MovementIssueResolver {
    static func resolve(for feedback: FormFeedback) -> MovementIssueKind? {
        if let kind = feedback.issueKind {
            return kind
        }
        return resolveLegacy(for: feedback)
    }

    private static func resolveLegacy(for feedback: FormFeedback) -> MovementIssueKind? {
        let message = feedback.message.trimmingCharacters(in: .whitespacesAndNewlines)

        // Exact string matches for known analyzer messages.
        if message == "Knees caving inward - push knees out to align with toes" {
            return .squatKneeValgus
        }
        if message == "Need to go deeper - aim to get hip crease below knee level" {
            return .squatDepthTooShallow
        }
        if message == "Incomplete range of motion - return to start or reach full depth" {
            return .squatIncompleteROM
        }

        // Category-aware legacy/preview variants.
        if feedback.category == .rangeOfMotion {
            if message.localizedCaseInsensitiveContains("shallow") {
                return .squatDepthTooShallow
            }
            if message.localizedCaseInsensitiveContains("incomplete range of motion") {
                return .squatIncompleteROM
            }
        }

        // Prefix matches for numeric / variable analyzer messages.
        if message.hasPrefix("Torso leaning too far forward") {
            return .squatForwardLean
        }
        if message.hasPrefix("Torso instability detected") {
            return .squatForwardLean
        }
        if message.hasPrefix("Hip shoot detected") {
            return .squatForwardLean
        }
        if message.hasPrefix("Balance drift detected") {
            return .squatHeelsLift
        }

        return nil
    }
}

enum SquatCueLibrary {
    struct Correctives {
        let strength: [String]
        let mobility: [String]
        let patterning: [String]
    }

    struct OverlayTargets {
        let joints: [BodyJoint]
        let segments: [(BodyJoint, BodyJoint)]
    }

    struct MessageTemplates {
        let overlayShort: String
        let repSummary: String
        let setSummary: String
    }

    struct Entry {
        let kind: MovementIssueKind
        let name: String
        let headline: String
        let oneLineDescription: String
        let poseHints: [String]
        let quickFix: String
        let quickFixRationale: String?
        let backupCues: [String]
        let correctives: Correctives
        let commonPhases: Set<SquatPhaseType>
        let overlayTargets: OverlayTargets
        let templates: MessageTemplates
    }

    private enum CommonCueText {
        static let tripodFoot = "Tripod foot"
        static let ankleDorsiflexion = "Ankle dorsiflexion"
        static let ribsDown = "Ribs down"
    }

    static func entry(for kind: MovementIssueKind) -> Entry? {
        switch kind {
        case .squatKneeValgus:
            return Entry(
                kind: kind,
                name: "Knee valgus",
                headline: "Knees caved in",
                oneLineDescription: "Knees move inward relative to toes/ankles, often near the bottom or during ascent.",
                poseHints: [
                    "Front view: knee joint drifts inward vs ankle/foot line.",
                    "Knee not tracking over 2nd/3rd toe.",
                    "Often coincides with foot collapse."
                ],
                quickFix: "Next rep: drive knees over 2nd/3rd toe + keep tripod foot.",
                quickFixRationale: nil,
                backupCues: ["Knees over toes.", "Spread the floor.", "Tripod foot."],
                correctives: Correctives(
                    strength: ["Lateral band walks", "Clamshells", "Split squats / Bulgarian split squats", "Single-leg RDL"],
                    mobility: ["Adductors", CommonCueText.ankleDorsiflexion],
                    patterning: ["Band-around-knees goblet squat holds/pauses"]
                ),
                commonPhases: [.bottom, .ascent],
                overlayTargets: OverlayTargets(
                    joints: [.leftHip, .rightHip, .leftKnee, .rightKnee],
                    segments: [(.leftHip, .leftKnee), (.rightHip, .rightKnee)]
                ),
                templates: MessageTemplates(
                    overlayShort: "Drive knees over toes.",
                    repSummary: "Knees caved in at the bottom.",
                    setSummary: "Knees caved in on multiple reps—keep knees tracking over toes."
                )
            )

        case .squatHeelsLift:
            return Entry(
                kind: kind,
                name: "Heels lifting",
                headline: "Heels lifted",
                oneLineDescription: "Heels rise or pressure shifts forward, often causing balance loss and forward lean.",
                poseHints: [
                    "Side view: heel rises vs baseline.",
                    "Knee stops traveling forward, heel pops.",
                    "Hip/bar path drifts forward relative to midfoot."
                ],
                quickFix: "Next rep: slow down into the bottom; keep heel planted.",
                quickFixRationale: "Often ankle-limited; fix with dorsiflexion work.",
                backupCues: ["Whole foot down.", "Heels heavy.", "Sit between hips."],
                correctives: Correctives(
                    strength: ["Heel-elevated squat (temporary regression)"],
                    mobility: ["Knee-to-wall dorsiflexion", "Calf stretch (straight + bent knee)", "Tibialis raises"],
                    patterning: ["Goblet squat counterbalance + pauses"]
                ),
                commonPhases: [.descent, .bottom],
                overlayTargets: OverlayTargets(
                    joints: [.leftHeel, .rightHeel, .leftAnkle, .rightAnkle, .leftFootIndex, .rightFootIndex],
                    segments: []
                ),
                templates: MessageTemplates(
                    overlayShort: "Keep the whole foot down.",
                    repSummary: "Heels lifted near the bottom.",
                    setSummary: "Heels lifted—slow the descent and keep the heel planted."
                )
            )

        case .squatForwardLean:
            return Entry(
                kind: kind,
                name: "Forward lean",
                headline: "Torso tipped forward",
                oneLineDescription: "Torso angle increases sharply near the bottom/out of the hole, shifting load and reducing control.",
                poseHints: [
                    "Side view: torso segment becomes more horizontal than typical.",
                    "Torso angle spikes at/after bottom.",
                    "Hips rise faster than shoulders."
                ],
                quickFix: "Next rep: brace harder + keep chest from collapsing out of the hole.",
                quickFixRationale: nil,
                backupCues: ["Push the floor away.", "Chest tall with ribs down.", "Brace before descent."],
                correctives: Correctives(
                    strength: ["Front squat", "Safety bar squat", "Tempo squats", "Quad-biased variations"],
                    mobility: [CommonCueText.ankleDorsiflexion],
                    patterning: ["Tempo into the bottom + controlled ascent"]
                ),
                commonPhases: [.bottom, .ascent],
                overlayTargets: OverlayTargets(
                    joints: [.leftShoulder, .rightShoulder, .leftHip, .rightHip],
                    segments: [(.leftShoulder, .leftHip), (.rightShoulder, .rightHip)]
                ),
                templates: MessageTemplates(
                    overlayShort: "Stay braced and keep chest tall.",
                    repSummary: "Torso tipped forward out of the bottom.",
                    setSummary: "Torso tipped forward—brace harder and keep the chest from collapsing."
                )
            )

        case .squatButtWink:
            return Entry(
                kind: kind,
                name: "Butt wink",
                headline: "Pelvis tucked at bottom",
                oneLineDescription: "Posterior pelvic tilt/lumbar rounding near depth; can be anatomy + depth + bracing.",
                poseHints: [
                    "Side view: pelvis tucks under at deepest frames.",
                    "Often only at the very bottom.",
                    "Correlates with depth beyond controlled ROM."
                ],
                quickFix: "Next rep: use slightly higher depth; keep brace through bottom.",
                quickFixRationale: "Some tuck can be normal; prioritize control.",
                backupCues: ["Brace + ribs down.", "Stop at depth you can own.", "Pause without losing position."],
                correctives: Correctives(
                    strength: [],
                    mobility: ["Supported deep squat holds", "90/90 work", "Adductor rocks"],
                    patterning: ["Tempo + pauses above wink depth", "Box to controlled depth"]
                ),
                commonPhases: [.bottom],
                overlayTargets: OverlayTargets(
                    joints: [.leftHip, .rightHip, .leftKnee, .rightKnee],
                    segments: [(.leftHip, .rightHip)]
                ),
                templates: MessageTemplates(
                    overlayShort: "Own your depth with a strong brace.",
                    repSummary: "Pelvis tucked at the bottom.",
                    setSummary: "Pelvis tucked at depth—use a depth you can control and keep the brace."
                )
            )

        case .squatHipShift:
            return Entry(
                kind: kind,
                name: "Hip shift",
                headline: "Shifted to one side",
                oneLineDescription: "Hips drift laterally and one side takes more load.",
                poseHints: [
                    "Front view: pelvis center translates left/right near bottom.",
                    "Asymmetry in knee cave or foot rotation.",
                    "Depth differs side-to-side."
                ],
                quickFix: "Next rep: slow the descent; keep pressure even across both feet.",
                quickFixRationale: nil,
                backupCues: ["Even pressure both feet.", "Stay centered over midfoot."],
                correctives: Correctives(
                    strength: ["Split squats", "Step-ups", "Single-leg RDL", "Single-leg leg press"],
                    mobility: ["Compare ankle dorsiflexion L/R", "Compare hip IR L/R"],
                    patterning: ["Paused reps with even pressure"]
                ),
                commonPhases: [.descent, .bottom],
                overlayTargets: OverlayTargets(
                    joints: [.leftHip, .rightHip, .leftKnee, .rightKnee, .leftAnkle, .rightAnkle],
                    segments: []
                ),
                templates: MessageTemplates(
                    overlayShort: "Stay centered over midfoot.",
                    repSummary: "Shifted to one side at the bottom.",
                    setSummary: "Shifted to one side—slow down and keep pressure even."
                )
            )

        case .squatBraceLeak:
            return Entry(
                kind: kind,
                name: "Loss of brace",
                headline: "Brace leaked",
                oneLineDescription: "Ribs flare and brace leaks, leading to instability and compensation.",
                poseHints: [
                    "Side view: trunk opens (ribcage rises relative to pelvis).",
                    "Often on descent or just out of the hole.",
                    "Neck extension and chest lift can accompany."
                ],
                quickFix: "Next rep: big breath into belly/sides before you descend.",
                quickFixRationale: nil,
                backupCues: [CommonCueText.ribsDown, "360° breath.", "Brace like you’ll be punched."],
                correctives: Correctives(
                    strength: ["Dead bug", "Pallof press", "Planks", "Carries"],
                    mobility: [],
                    patterning: ["Paused squats with breath/brace check"]
                ),
                commonPhases: [.setup, .descent, .ascent],
                overlayTargets: OverlayTargets(
                    joints: [.leftShoulder, .rightShoulder, .leftHip, .rightHip],
                    segments: []
                ),
                templates: MessageTemplates(
                    overlayShort: "Breathe + brace (360°) before you move.",
                    repSummary: "Brace leaked during the rep.",
                    setSummary: "Brace leaked—reset with a big 360° breath and ribs down."
                )
            )

        case .squatKneesStayedBack:
            return Entry(
                kind: kind,
                name: "Knees stayed back",
                headline: "Knees stayed back",
                oneLineDescription: "Shins stay too vertical, forcing a hip-dominant pattern and extra hinge.",
                poseHints: [
                    "Side view: knee forward displacement small relative to depth.",
                    "Shin angle stays too vertical.",
                    "Often paired with forward lean or heel lift attempts."
                ],
                quickFix: "Next rep: allow knees forward while keeping full foot down.",
                quickFixRationale: "Knees over toes is okay if controlled.",
                backupCues: ["Let knees go forward.", "Sit down, not back."],
                correctives: Correctives(
                    strength: ["ATG split squats"],
                    mobility: [CommonCueText.ankleDorsiflexion],
                    patterning: ["Heel-elevated squats", "Slant board squats"]
                ),
                commonPhases: [.descent, .bottom],
                overlayTargets: OverlayTargets(
                    joints: [.leftKnee, .rightKnee, .leftAnkle, .rightAnkle, .leftHeel, .rightHeel],
                    segments: []
                ),
                templates: MessageTemplates(
                    overlayShort: "Let the knees travel forward.",
                    repSummary: "Knees stayed back.",
                    setSummary: "Knees stayed back—allow knees forward while keeping the whole foot down."
                )
            )

        case .squatFootCollapse:
            return Entry(
                kind: kind,
                name: "Foot collapse",
                headline: "Foot lost tripod",
                oneLineDescription: "Foot loses tripod and arch collapses, increasing valgus and instability.",
                poseHints: [
                    "Front view: ankle and knee move inward together.",
                    "Foot progression angle changes mid-rep.",
                    "Often appears with valgus + heel lift."
                ],
                quickFix: "Next rep: set tripod before descent; keep big toe down.",
                quickFixRationale: nil,
                backupCues: ["Tripod foot.", "Big toe down.", "Screw feet into the floor."],
                correctives: Correctives(
                    strength: ["Short-foot drills", "Calf raises", "Tibialis raises", "Single-leg balance"],
                    mobility: [],
                    patterning: ["Goblet squat with foot lock-in setup"]
                ),
                commonPhases: [.setup, .descent],
                overlayTargets: OverlayTargets(
                    joints: [.leftAnkle, .rightAnkle, .leftHeel, .rightHeel, .leftFootIndex, .rightFootIndex],
                    segments: []
                ),
                templates: MessageTemplates(
                    overlayShort: "Keep a strong tripod foot.",
                    repSummary: "Foot collapsed during the rep.",
                    setSummary: "Foot lost tripod—set the foot before descent and keep big toe down."
                )
            )

        case .squatDepthTooShallow:
            return Entry(
                kind: kind,
                name: "Shallow depth",
                headline: "Depth was shallow",
                oneLineDescription: "Depth varies or misses target depth.",
                poseHints: ["Hip crease stays above knee height."],
                quickFix: "Next rep: aim for consistent depth you can own (work toward hip crease below knee).",
                quickFixRationale: nil,
                backupCues: ["Same depth each rep."],
                correctives: Correctives(
                    strength: [],
                    mobility: [],
                    patterning: ["Tempo sets", "Paused reps", "Box target"]
                ),
                commonPhases: [.bottom],
                overlayTargets: OverlayTargets(
                    joints: [.leftHip, .rightHip, .leftKnee, .rightKnee],
                    segments: []
                ),
                templates: MessageTemplates(
                    overlayShort: "Own a consistent depth.",
                    repSummary: "Depth was shallow.",
                    setSummary: "Depth was shallow—work toward consistent depth you can control."
                )
            )

        case .squatIncompleteROM:
            return Entry(
                kind: kind,
                name: "Incomplete ROM",
                headline: "Incomplete range of motion",
                oneLineDescription: "Did not return to start or reach full depth.",
                poseHints: ["Rep does not complete full range of motion."],
                quickFix: "Next rep: stand all the way up and hit your target depth.",
                quickFixRationale: nil,
                backupCues: [],
                correctives: Correctives(strength: [], mobility: [], patterning: ["Tempo reps with full ROM"]),
                commonPhases: [.descent, .ascent],
                overlayTargets: OverlayTargets(
                    joints: [.leftHip, .rightHip, .leftKnee, .rightKnee],
                    segments: []
                ),
                templates: MessageTemplates(
                    overlayShort: "Full ROM: depth + full stand.",
                    repSummary: "Incomplete ROM.",
                    setSummary: "Incomplete ROM—complete each rep with full depth and full stand."
                )
            )

        case .squatDepthInconsistent:
            return Entry(
                kind: kind,
                name: "Depth inconsistency",
                headline: "Depth changed across reps",
                oneLineDescription: "Rep depth varies across the set.",
                poseHints: ["Bottom position changes rep-to-rep."],
                quickFix: "Next set: pick a target depth and repeat it every rep.",
                quickFixRationale: nil,
                backupCues: ["Same depth each rep."],
                correctives: Correctives(strength: [], mobility: [], patterning: ["Tempo sets", "Paused reps", "Box target"]),
                commonPhases: [.bottom],
                overlayTargets: OverlayTargets(
                    joints: [.leftHip, .rightHip, .leftKnee, .rightKnee],
                    segments: []
                ),
                templates: MessageTemplates(
                    overlayShort: "Repeat the same depth.",
                    repSummary: "Depth changed across reps.",
                    setSummary: "Depth changed across reps—choose a target depth and repeat it."
                )
            )

        default:
            return nil
        }
    }
}
