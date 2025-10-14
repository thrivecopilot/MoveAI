//
//  MovementCard.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import SwiftUI

struct MovementCard: View {
    let movement: Movement
    let onTap: () -> Void
    var showProgress: Bool = false
    var progressScore: Double = 0.0
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                // Header with icon and category
                HStack {
                    Image(systemName: movement.category.icon)
                        .font(.title2)
                        .foregroundColor(DesignSystem.Colors.primary)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text(movement.category.rawValue)
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        
                        DifficultyBadge(difficulty: movement.difficulty)
                    }
                }
                
                // Movement name and description
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(movement.name)
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .multilineTextAlignment(.leading)
                    
                    Text(movement.description)
                        .font(DesignSystem.Typography.callout)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                // Equipment tags
                if !movement.equipment.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            ForEach(movement.equipment, id: \.self) { equipment in
                                EquipmentTag(equipment: equipment)
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                }
                
                // Progress indicator (if applicable)
                if showProgress {
                    ProgressIndicator(score: progressScore)
                }
            }
            .padding(DesignSystem.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignSystem.Colors.surface)
            .cornerRadius(DesignSystem.CornerRadius.large)
            .shadowSmall()
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct DifficultyBadge: View {
    let difficulty: DifficultyLevel
    
    var body: some View {
        Text(difficulty.rawValue)
            .font(DesignSystem.Typography.caption)
            .fontWeight(.medium)
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(
                Capsule()
                    .fill(difficultyColor.opacity(0.2))
            )
            .foregroundColor(difficultyColor)
    }
    
    private var difficultyColor: Color {
        switch difficulty {
        case .beginner: return DesignSystem.Colors.success
        case .intermediate: return DesignSystem.Colors.info
        case .advanced: return DesignSystem.Colors.warning
        case .expert: return DesignSystem.Colors.error
        }
    }
}

struct EquipmentTag: View {
    let equipment: Equipment
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: equipment.icon)
                .font(.caption)
            
            Text(equipment.rawValue)
                .font(DesignSystem.Typography.caption)
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(
            Capsule()
                .fill(DesignSystem.Colors.primary.opacity(0.1))
        )
        .foregroundColor(DesignSystem.Colors.primary)
    }
}

struct ProgressIndicator: View {
    let score: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack {
                Text("Progress")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                
                Spacer()
                
                Text("\(Int(score))%")
                    .font(DesignSystem.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(progressColor)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 4)
                    
                    Rectangle()
                        .fill(progressColor)
                        .frame(width: geometry.size.width * (score / 100.0), height: 4)
                }
            }
            .frame(height: 4)
        }
    }
    
    private var progressColor: Color {
        switch score {
        case 0..<40: return DesignSystem.Colors.error
        case 40..<70: return DesignSystem.Colors.warning
        case 70..<90: return DesignSystem.Colors.info
        default: return DesignSystem.Colors.success
        }
    }
}

struct MovementGridCard: View {
    let movement: Movement
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: DesignSystem.Spacing.sm) {
                // Icon
                Image(systemName: movement.category.icon)
                    .font(.system(size: DesignSystem.ComponentSize.iconXLarge))
                    .foregroundColor(DesignSystem.Colors.primary)
                    .frame(height: DesignSystem.ComponentSize.iconXLarge)
                
                // Name
                Text(movement.name)
                    .font(DesignSystem.Typography.callout)
                    .fontWeight(.medium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                // Difficulty
                DifficultyBadge(difficulty: movement.difficulty)
            }
            .padding(DesignSystem.Spacing.md)
            .frame(maxWidth: .infinity)
            .frame(height: DesignSystem.ComponentSize.cardMinHeight)
            .background(DesignSystem.Colors.surface)
            .cornerRadius(DesignSystem.CornerRadius.large)
            .shadowSmall()
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ScrollView {
        LazyVStack(spacing: DesignSystem.Spacing.md) {
            MovementCard(
                movement: Movement(
                    name: "Barbell Back Squat",
                    category: .powerlifting,
                    description: "The king of lower body exercises, targeting quadriceps, glutes, and hamstrings.",
                    idealForm: IdealForm(),
                    difficulty: .intermediate,
                    equipment: [.barbell, .plates, .rack]
                ),
                onTap: {},
                showProgress: true,
                progressScore: 75.0
            )
            
            MovementCard(
                movement: Movement(
                    name: "Conventional Deadlift",
                    category: .powerlifting,
                    description: "A compound movement targeting the posterior chain.",
                    idealForm: IdealForm(),
                    difficulty: .advanced,
                    equipment: [.barbell, .plates, .belt]
                ),
                onTap: {}
            )
        }
        .padding()
    }
}
