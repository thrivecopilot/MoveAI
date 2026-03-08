import SwiftUI

enum CoachTheme {
    enum Palette {
        static let accent = Color(red: 0.24, green: 0.86, blue: 1.0)
        static let success = Color.green
        static let warning = Color.orange
        static let danger = Color.red

        static func screenGradient(for scheme: ColorScheme) -> LinearGradient {
            if scheme == .dark {
                return LinearGradient(
                    colors: [
                        Color(red: 0.04, green: 0.08, blue: 0.14),
                        Color(red: 0.06, green: 0.10, blue: 0.16),
                        Color(red: 0.04, green: 0.06, blue: 0.10),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }

            return LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.98, blue: 1.0),
                    Color(red: 0.97, green: 0.98, blue: 0.99),
                    Color(red: 0.94, green: 0.96, blue: 0.98),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }

        static func surfaceFill(for scheme: ColorScheme) -> LinearGradient {
            if scheme == .dark {
                return LinearGradient(
                    colors: [
                        Color(red: 0.10, green: 0.14, blue: 0.20).opacity(0.92),
                        Color(red: 0.07, green: 0.10, blue: 0.16).opacity(0.92),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            return LinearGradient(
                colors: [
                    Color.white.opacity(0.93),
                    Color(red: 0.94, green: 0.96, blue: 0.99).opacity(0.90),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        static func elevatedSurfaceFill(for scheme: ColorScheme) -> LinearGradient {
            if scheme == .dark {
                return LinearGradient(
                    colors: [
                        Color(red: 0.11, green: 0.19, blue: 0.28),
                        Color(red: 0.07, green: 0.12, blue: 0.20),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            return LinearGradient(
                colors: [
                    Color(red: 0.87, green: 0.94, blue: 1.0),
                    Color(red: 0.92, green: 0.96, blue: 1.0),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        static func stroke(for scheme: ColorScheme) -> Color {
            scheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.08)
        }

        static func chromeBackground(for scheme: ColorScheme) -> Color {
            scheme == .dark ? Color.black.opacity(0.96) : Color.white.opacity(0.95)
        }

        static func secondarySurface(for scheme: ColorScheme) -> Color {
            scheme == .dark ? Color.white.opacity(0.07) : Color.black.opacity(0.05)
        }

        static func chipBackground(_ tint: Color, for scheme: ColorScheme) -> Color {
            scheme == .dark ? tint.opacity(0.20) : tint.opacity(0.16)
        }
    }

    enum Typography {
        static let screenTitle = Font.system(size: 28, weight: .bold, design: .rounded)
        static let sectionTitle = Font.system(size: 28, weight: .bold)
        static let cardTitle = Font.system(size: 22, weight: .bold)
        static let title = Font.system(size: 20, weight: .semibold)
        static let subtitle = Font.system(size: 16, weight: .semibold)
        static let body = Font.system(size: 16, weight: .regular)
        static let meta = Font.system(size: 13, weight: .medium)
        static let caption = Font.system(size: 12, weight: .semibold)
        static let chip = Font.system(size: 13, weight: .semibold)
    }

    enum Corners {
        static let card: CGFloat = 18
        static let control: CGFloat = 12
        static let chip: CGFloat = 999
    }

    enum Motion {
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.18)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.25)
        static let spring = SwiftUI.Animation.spring(response: 0.32, dampingFraction: 0.88)
    }

    enum Surfaces {
        static let cardPadding: CGFloat = 14
        static let cardSpacing: CGFloat = 12
    }
}
