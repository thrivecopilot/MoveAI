import SwiftUI

struct CoachScreenBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        CoachTheme.Palette.screenGradient(for: colorScheme)
            .ignoresSafeArea()
    }
}

struct CoachCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme

    var elevated: Bool = false
    var cornerRadius: CGFloat = CoachTheme.Corners.card
    var padding: CGFloat = CoachTheme.Surfaces.cardPadding
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(elevated ? CoachTheme.Palette.elevatedSurfaceFill(for: colorScheme) : CoachTheme.Palette.surfaceFill(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(CoachTheme.Palette.stroke(for: colorScheme), lineWidth: 1)
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.08),
                radius: 12,
                x: 0,
                y: 8
            )
    }
}

struct CoachChip: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    var tint: Color = CoachTheme.Palette.accent
    var minWidth: CGFloat? = nil
    var maxWidth: CGFloat? = nil
    var height: CGFloat = 30

    var body: some View {
        Text(title)
            .font(CoachTheme.Typography.chip)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .allowsTightening(true)
            .padding(.horizontal, 12)
            .frame(minWidth: minWidth, maxWidth: maxWidth)
            .frame(height: height)
            .foregroundColor(tint)
            .background(CoachTheme.Palette.chipBackground(tint, for: colorScheme))
            .clipShape(Capsule(style: .continuous))
    }
}

struct CoachSectionHeader: View {
    let icon: String
    let title: String
    var tint: Color = CoachTheme.Palette.accent

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(tint)
            Text(title)
                .font(CoachTheme.Typography.title)
            Spacer()
        }
    }
}

struct CoachPrimaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CoachTheme.Typography.subtitle)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundColor(CoachTheme.Palette.accent)
            .background(
                RoundedRectangle(cornerRadius: CoachTheme.Corners.control, style: .continuous)
                    .fill(CoachTheme.Palette.accent.opacity(colorScheme == .dark ? 0.24 : 0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: CoachTheme.Corners.control, style: .continuous)
                    .stroke(CoachTheme.Palette.accent.opacity(0.35), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(CoachTheme.Motion.quick, value: configuration.isPressed)
    }
}

struct CoachSecondaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CoachTheme.Typography.subtitle)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundColor(.primary)
            .background(
                RoundedRectangle(cornerRadius: CoachTheme.Corners.control, style: .continuous)
                    .fill(CoachTheme.Palette.secondarySurface(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: CoachTheme.Corners.control, style: .continuous)
                    .stroke(CoachTheme.Palette.stroke(for: colorScheme), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(CoachTheme.Motion.quick, value: configuration.isPressed)
    }
}

struct CoachNavigationChromeModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
            .tint(CoachTheme.Palette.accent)
    }
}

extension View {
    func coachNavigationChrome() -> some View {
        modifier(CoachNavigationChromeModifier())
    }

    func coachScreenContainer() -> some View {
        self
            .background(CoachScreenBackground())
            .tint(CoachTheme.Palette.accent)
    }
}
