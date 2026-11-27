import SwiftUI

struct MuayThaiTechniqueSelectionView: View {
    let onConfirm: (MuayThaiTechnique?, FightStance?) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedTechnique: MuayThaiTechnique
    @State private var selectedStance: FightStance
    @State private var useAutoDetect: Bool

    init(onConfirm: @escaping (MuayThaiTechnique?, FightStance?) -> Void) {
        self.onConfirm = onConfirm
        let memory = MuayThaiSelectionMemory.load()
        _selectedTechnique = State(initialValue: memory.technique)
        _selectedStance = State(initialValue: memory.stance)
        _useAutoDetect = State(initialValue: memory.useAutoDetect)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: CoachTheme.Surfaces.groupSpacing) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Technique")
                        .font(CoachTheme.Typography.subtitle)

                    Picker("Technique Mode", selection: $useAutoDetect) {
                        Text("Auto Detect").tag(true)
                        Text("Choose").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("MuayThai.ModePicker")

                    Text(useAutoDetect
                        ? "We'll detect the primary movement from this clip before analysis."
                        : "Choose the movement you're training for targeted feedback.")
                        .font(CoachTheme.Typography.meta)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, CoachTheme.Surfaces.screenHorizontalPadding)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Stance")
                        .font(CoachTheme.Typography.subtitle)
                    Picker("Stance", selection: $selectedStance) {
                        Text("Auto Infer").tag(FightStance.unknown)
                        Text(FightStance.orthodox.displayName).tag(FightStance.orthodox)
                        Text(FightStance.southpaw.displayName).tag(FightStance.southpaw)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("MuayThai.StancePicker")

                    Text("Orthodox leads with the left foot, southpaw with the right. Auto Infer reads it from your clip.")
                        .font(CoachTheme.Typography.meta)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, CoachTheme.Surfaces.screenHorizontalPadding)

                ScrollView {
                    if useAutoDetect {
                        autoDetectCard
                            .padding(.horizontal, CoachTheme.Surfaces.screenHorizontalPadding)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(MuayThaiTechnique.allCases) { technique in
                                techniqueRow(technique)
                            }
                        }
                        .padding(.horizontal, CoachTheme.Surfaces.screenHorizontalPadding)
                    }
                }

                Button {
                    let stance: FightStance? = selectedStance == .unknown ? nil : selectedStance
                    let technique: MuayThaiTechnique? = useAutoDetect ? nil : selectedTechnique
                    MuayThaiSelectionMemory(
                        useAutoDetect: useAutoDetect,
                        technique: selectedTechnique,
                        stance: selectedStance
                    ).save()
                    onConfirm(technique, stance)
                } label: {
                    Text(useAutoDetect ? "Continue with Auto Detect" : "Continue with \(selectedTechnique.displayName)")
                        .font(CoachTheme.Typography.subtitle)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(CoachTheme.Palette.accent)
                        .foregroundColor(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(.horizontal, CoachTheme.Surfaces.screenHorizontalPadding)
                .padding(.bottom, 8)
                .accessibilityIdentifier("MuayThai.ContinueButton")
            }
            .padding(.top, 12)
            .navigationTitle("Muay Thai")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .coachScreenContainer()
            .accessibilityIdentifier("MuayThai.TechniqueSelection")
            .accessibilityElement(children: .contain)
        }
    }

    private var autoDetectCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "wand.and.stars")
                    .foregroundColor(CoachTheme.Palette.accent)
                Text("Auto Detect enabled")
                    .font(CoachTheme.Typography.subtitle)
            }
            Text(MuayThaiTechnique.autoDetectCaptureTip)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(CoachTheme.Palette.surfaceFill(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(CoachTheme.Palette.stroke(for: colorScheme), lineWidth: 1)
        )
    }

    private func techniqueRow(_ technique: MuayThaiTechnique) -> some View {
        let isSelected = selectedTechnique == technique
        return Button {
            selectedTechnique = technique
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? CoachTheme.Palette.accent : .secondary)

                VStack(alignment: .leading, spacing: 3) {
                    Text(technique.displayName)
                        .font(CoachTheme.Typography.subtitle)
                        .foregroundColor(.primary)
                    Text(technique.category.displayName)
                        .font(CoachTheme.Typography.meta)
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 0)

                coverageBadge(for: technique)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(CoachTheme.Palette.surfaceFill(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isSelected ? CoachTheme.Palette.accent.opacity(0.7) : CoachTheme.Palette.stroke(for: colorScheme),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("MuayThai.TechniqueRow.\(technique.rawValue)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Sets expectations before recording: not every technique has equally deep checks.
    private func coverageBadge(for technique: MuayThaiTechnique) -> some View {
        let (label, color): (String, Color) = {
            switch technique.analysisDepth {
            case .validated:
                return ("Full analysis", CoachTheme.Palette.accent)
            case .early:
                return ("Early checks", .orange)
            }
        }()

        return Text(label)
            .font(.caption2.weight(.semibold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(color.opacity(0.14))
            )
    }
}

#Preview {
    MuayThaiTechniqueSelectionView { _, _ in }
}
