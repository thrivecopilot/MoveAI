import SwiftUI

struct MuayThaiTechniqueSelectionView: View {
    let onConfirm: (MuayThaiTechnique, FightStance) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTechnique: MuayThaiTechnique = .jab
    @State private var selectedStance: FightStance = .orthodox

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Stance")
                        .font(.headline)
                    Picker("Stance", selection: $selectedStance) {
                        Text(FightStance.orthodox.displayName).tag(FightStance.orthodox)
                        Text(FightStance.southpaw.displayName).tag(FightStance.southpaw)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal, 16)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(MuayThaiTechniqueCategory.allCases) { category in
                            let techniques = MuayThaiTechnique.allCases.filter { $0.category == category }
                            if !techniques.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(category.displayName)
                                        .font(.headline)
                                        .foregroundColor(.secondary)

                                    ForEach(techniques) { technique in
                                        Button {
                                            selectedTechnique = technique
                                        } label: {
                                            HStack {
                                                Text(technique.displayName)
                                                    .font(.body)
                                                    .foregroundColor(.primary)
                                                Spacer()
                                                if selectedTechnique == technique {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundColor(.accentColor)
                                                } else {
                                                    Image(systemName: "circle")
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                            .padding(12)
                                            .background(Color(.systemGray6))
                                            .cornerRadius(10)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }

                Button {
                    onConfirm(selectedTechnique, selectedStance)
                    dismiss()
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            .navigationTitle("Muay Thai")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    MuayThaiTechniqueSelectionView { _, _ in }
}
