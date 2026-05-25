import SwiftUI

struct CueOverlayView: View {
    let overlay: CoachingCueOverlay
    
    private let background = Color(red: 0.08, green: 0.10, blue: 0.14)
    private let stroke = Color.white.opacity(0.08)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: severityIcon(overlay.severity))
                    .font(.caption)
                    .foregroundColor(severityColor(overlay.severity))
                Text(overlay.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .accessibilityIdentifier(AccessibilityID.CueOverlay.title)
                Spacer(minLength: 0)
            }
            
            Text("Quick fix: \(overlay.cue.shortText)")
                .font(.subheadline)
                .foregroundColor(.white)
                .lineLimit(2)
                .accessibilityIdentifier(AccessibilityID.CueOverlay.quickFix)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(background)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(stroke, lineWidth: 1)
        )
        .cornerRadius(12)
        .accessibilityIdentifier(AccessibilityID.CueOverlay.root)
        .accessibilityElement(children: .contain)
    }
    
    private func severityIcon(_ severity: FeedbackSeverity) -> String {
        switch severity {
        case .critical: return "exclamationmark.octagon.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .good, .excellent: return "checkmark.circle.fill"
        }
    }
    
    private func severityColor(_ severity: FeedbackSeverity) -> Color {
        switch severity {
        case .critical: return Color(red: 1.0, green: 0.42, blue: 0.42)
        case .warning: return Color(red: 1.0, green: 0.68, blue: 0.3)
        case .good: return Color(red: 0.16, green: 0.97, blue: 0.65)
        case .excellent: return Color(red: 0.24, green: 0.86, blue: 1.0)
        }
    }
}
