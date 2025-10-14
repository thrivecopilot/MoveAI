//
//  PrimaryButton.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import SwiftUI

struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    var isEnabled: Bool = true
    var isLoading: Bool = false
    var size: ButtonSize = .medium
    var icon: String? = nil
    
    enum ButtonSize {
        case small, medium, large
        
        var height: CGFloat {
            switch self {
            case .small: return DesignSystem.ComponentSize.buttonSmall
            case .medium: return DesignSystem.ComponentSize.buttonMedium
            case .large: return DesignSystem.ComponentSize.buttonLarge
            }
        }
        
        var font: Font {
            switch self {
            case .small: return DesignSystem.Typography.callout
            case .medium: return DesignSystem.Typography.headline
            case .large: return DesignSystem.Typography.title3
            }
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(size.font)
                }
                
                Text(title)
                    .font(size.font)
                    .fontWeight(.semibold)
            }
            .frame(height: size.height)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .fill(isEnabled ? DesignSystem.Colors.primary : DesignSystem.Colors.textTertiary)
            )
            .foregroundColor(.white)
        }
        .disabled(!isEnabled || isLoading)
        .animation(DesignSystem.Animation.quick, value: isLoading)
    }
}

struct SecondaryButton: View {
    let title: String
    let action: () -> Void
    var isEnabled: Bool = true
    var isLoading: Bool = false
    var size: PrimaryButton.ButtonSize = .medium
    var icon: String? = nil
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.primary))
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(size.font)
                }
                
                Text(title)
                    .font(size.font)
                    .fontWeight(.semibold)
            }
            .frame(height: size.height)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .stroke(DesignSystem.Colors.primary, lineWidth: 1)
            )
            .foregroundColor(DesignSystem.Colors.primary)
        }
        .disabled(!isEnabled || isLoading)
        .animation(DesignSystem.Animation.quick, value: isLoading)
    }
}

struct IconButton: View {
    let icon: String
    let action: () -> Void
    var size: CGFloat = DesignSystem.ComponentSize.iconMedium
    var color: Color = DesignSystem.Colors.primary
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size))
                .foregroundColor(color)
                .frame(width: size + DesignSystem.Spacing.md, height: size + DesignSystem.Spacing.md)
                .background(
                    Circle()
                        .fill(DesignSystem.Colors.surface)
                        .shadowSmall()
                )
        }
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spacing.lg) {
        PrimaryButton(title: "Primary Button", action: {})
        
        PrimaryButton(
            title: "Loading Button",
            action: {},
            isLoading: true
        )
        
        PrimaryButton(
            title: "Disabled Button",
            action: {},
            isEnabled: false
        )
        
        PrimaryButton(
            title: "With Icon",
            action: {},
            icon: "camera.fill"
        )
        
        SecondaryButton(title: "Secondary Button", action: {})
        
        HStack {
            IconButton(icon: "heart.fill", action: {})
            IconButton(icon: "star.fill", action: {})
            IconButton(icon: "share.fill", action: {})
        }
    }
    .padding()
}
