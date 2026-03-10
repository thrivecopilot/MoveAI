import Foundation

enum AnalysisUnitKind: String, Codable {
    case rep
    case strike
    case attempt

    var summaryTitle: String {
        switch self {
        case .rep:
            return "Rep Summary"
        case .strike:
            return "Strike Summary"
        case .attempt:
            return "Attempt Summary"
        }
    }
}

struct AnalysisSummary: Codable {
    let unitKind: AnalysisUnitKind
    let totalUnits: Int
    let goodUnits: Int
    let unitsNeedingAttention: Int
    let warningEvents: Int

    init(
        unitKind: AnalysisUnitKind,
        totalUnits: Int,
        goodUnits: Int,
        unitsNeedingAttention: Int,
        warningEvents: Int
    ) {
        self.unitKind = unitKind
        self.totalUnits = max(0, totalUnits)
        self.goodUnits = max(0, goodUnits)
        self.unitsNeedingAttention = max(0, unitsNeedingAttention)
        self.warningEvents = max(0, warningEvents)
    }
}
