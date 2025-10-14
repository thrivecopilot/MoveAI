//
//  DesignSystem.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import SwiftUI

// MARK: - Design System Constants

struct DesignSystem {
    
    // MARK: - Spacing (8pt Grid System)
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        static let xxxl: CGFloat = 64
    }
    
    // MARK: - Typography
    struct Typography {
        static let largeTitle = Font.largeTitle.weight(.bold)
        static let title1 = Font.title.weight(.semibold)
        static let title2 = Font.title2.weight(.medium)
        static let title3 = Font.title3.weight(.medium)
        static let headline = Font.headline.weight(.semibold)
        static let body = Font.body
        static let callout = Font.callout
        static let subheadline = Font.subheadline
        static let footnote = Font.footnote
        static let caption = Font.caption
    }
    
    // MARK: - Colors
    struct Colors {
        // Primary Colors
        static let primary = Color("PrimaryColor")
        static let primaryLight = Color("PrimaryLightColor")
        static let primaryDark = Color("PrimaryDarkColor")
        
        // Secondary Colors
        static let secondary = Color("SecondaryColor")
        static let secondaryLight = Color("SecondaryLightColor")
        
        // Accent Colors
        static let accent = Color("AccentColor")
        static let accentLight = Color("AccentLightColor")
        
        // Semantic Colors
        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red
        static let info = Color.blue
        
        // Neutral Colors
        static let background = Color("BackgroundColor")
        static let surface = Color("SurfaceColor")
        static let onSurface = Color("OnSurfaceColor")
        static let onBackground = Color("OnBackgroundColor")
        
        // Text Colors
        static let textPrimary = Color.primary
        static let textSecondary = Color.secondary
        static let textTertiary = Color(UIColor.tertiaryLabel)
        
        // Border Colors
        static let border = Color(UIColor.separator)
        static let borderLight = Color(UIColor.opaqueSeparator)
    }
    
    // MARK: - Component Sizes
    struct ComponentSize {
        // Button Heights
        static let buttonSmall: CGFloat = 32
        static let buttonMedium: CGFloat = 44
        static let buttonLarge: CGFloat = 56
        
        // Card Dimensions
        static let cardMinHeight: CGFloat = 120
        static let cardMaxHeight: CGFloat = 200
        
        // Input Heights
        static let inputHeight: CGFloat = 44
        static let textFieldHeight: CGFloat = 44
        
        // Icon Sizes
        static let iconSmall: CGFloat = 16
        static let iconMedium: CGFloat = 24
        static let iconLarge: CGFloat = 32
        static let iconXLarge: CGFloat = 48
        
        // Avatar Sizes
        static let avatarSmall: CGFloat = 32
        static let avatarMedium: CGFloat = 48
        static let avatarLarge: CGFloat = 64
    }
    
    // MARK: - Corner Radius
    struct CornerRadius {
        static let small: CGFloat = 4
        static let medium: CGFloat = 8
        static let large: CGFloat = 12
        static let xLarge: CGFloat = 16
        static let round: CGFloat = 999
    }
    
    // MARK: - Shadows
    struct Shadow {
        static let small = ShadowStyle(
            color: Color.black.opacity(0.1),
            radius: 2,
            x: 0,
            y: 1
        )
        
        static let medium = ShadowStyle(
            color: Color.black.opacity(0.15),
            radius: 4,
            x: 0,
            y: 2
        )
        
        static let large = ShadowStyle(
            color: Color.black.opacity(0.2),
            radius: 8,
            x: 0,
            y: 4
        )
    }
    
    // MARK: - Animation
    struct Animation {
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.5)
        static let spring = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.8)
    }
}

// MARK: - Shadow Style Helper
struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - View Modifiers
extension View {
    
    // MARK: - Spacing Modifiers
    func paddingXS() -> some View {
        padding(DesignSystem.Spacing.xs)
    }
    
    func paddingSM() -> some View {
        padding(DesignSystem.Spacing.sm)
    }
    
    func paddingMD() -> some View {
        padding(DesignSystem.Spacing.md)
    }
    
    func paddingLG() -> some View {
        padding(DesignSystem.Spacing.lg)
    }
    
    func paddingXL() -> some View {
        padding(DesignSystem.Spacing.xl)
    }
    
    // MARK: - Shadow Modifiers
    func shadowSmall() -> some View {
        shadow(
            color: DesignSystem.Shadow.small.color,
            radius: DesignSystem.Shadow.small.radius,
            x: DesignSystem.Shadow.small.x,
            y: DesignSystem.Shadow.small.y
        )
    }
    
    func shadowMedium() -> some View {
        shadow(
            color: DesignSystem.Shadow.medium.color,
            radius: DesignSystem.Shadow.medium.radius,
            x: DesignSystem.Shadow.medium.x,
            y: DesignSystem.Shadow.medium.y
        )
    }
    
    func shadowLarge() -> some View {
        shadow(
            color: DesignSystem.Shadow.large.color,
            radius: DesignSystem.Shadow.large.radius,
            x: DesignSystem.Shadow.large.x,
            y: DesignSystem.Shadow.large.y
        )
    }
    
    // MARK: - Corner Radius Modifiers
    func cornerRadiusSmall() -> some View {
        cornerRadius(DesignSystem.CornerRadius.small)
    }
    
    func cornerRadiusMedium() -> some View {
        cornerRadius(DesignSystem.CornerRadius.medium)
    }
    
    func cornerRadiusLarge() -> some View {
        cornerRadius(DesignSystem.CornerRadius.large)
    }
    
    func cornerRadiusXLarge() -> some View {
        cornerRadius(DesignSystem.CornerRadius.xLarge)
    }
    
    // MARK: - Card Style
    func cardStyle() -> some View {
        self
            .background(DesignSystem.Colors.surface)
            .cornerRadiusMedium()
            .shadowSmall()
    }
    
    // MARK: - Button Style
    func primaryButtonStyle() -> some View {
        self
            .frame(height: DesignSystem.ComponentSize.buttonMedium)
            .background(DesignSystem.Colors.primary)
            .foregroundColor(.white)
            .cornerRadiusMedium()
            .shadowSmall()
    }
    
    func secondaryButtonStyle() -> some View {
        self
            .frame(height: DesignSystem.ComponentSize.buttonMedium)
            .background(DesignSystem.Colors.surface)
            .foregroundColor(DesignSystem.Colors.primary)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .stroke(DesignSystem.Colors.primary, lineWidth: 1)
            )
    }
    
    // MARK: - Input Style
    func inputFieldStyle() -> some View {
        self
            .frame(height: DesignSystem.ComponentSize.inputHeight)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.surface)
            .cornerRadiusMedium()
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .stroke(DesignSystem.Colors.border, lineWidth: 1)
            )
    }
}

// MARK: - Color Extensions
extension Color {
    init(_ colorName: String) {
        self.init(UIColor(named: colorName) ?? UIColor.systemBlue)
    }
}
