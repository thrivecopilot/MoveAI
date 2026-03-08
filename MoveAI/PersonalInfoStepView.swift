//
//  PersonalInfoStepView.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import SwiftUI

struct PersonalInfoStepView: View {
    let onComplete: () -> Void

    @AppStorage("userHeight") private var userHeight: Double = 0
    @AppStorage("userWeight") private var userWeight: Double = 0
    @AppStorage("userAge") private var userAge: Int = 0

    @State private var heightFeet: Int = 5
    @State private var heightInches: Int = 8
    @State private var weightPounds: Double = 150
    @State private var age: Int = 25

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                CoachCard(elevated: true) {
                    VStack(spacing: 14) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 56, weight: .semibold))
                            .foregroundColor(CoachTheme.Palette.accent)
                            .accessibilityIdentifier("DataInput.Icon")

                        Text("Review Your Information")
                            .font(CoachTheme.Typography.cardTitle)
                            .accessibilityIdentifier("DataInput.Title")

                        Text(hasExistingData ? "Your information was synced from Apple Health. You can edit it below if needed." : "This helps us personalize your movement analysis")
                            .font(CoachTheme.Typography.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("DataInput.Subtitle")
                    }
                    .frame(maxWidth: .infinity)
                }

                CoachCard {
                    VStack(spacing: 18) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Height")
                                .font(.headline)
                                .accessibilityIdentifier("DataInput.HeightTitle")
                            HStack {
                                Picker("Feet", selection: $heightFeet) {
                                    ForEach(0..<9) { feet in
                                        Text("\(feet) ft").tag(feet)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 100, height: 120)
                                .clipped()
                                .accessibilityIdentifier("DataInput.HeightFeetPicker")

                                Picker("Inches", selection: $heightInches) {
                                    ForEach(0..<12) { inches in
                                        Text("\(inches) in").tag(inches)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 100, height: 120)
                                .clipped()
                                .accessibilityIdentifier("DataInput.HeightInchesPicker")
                            }
                            .padding(.horizontal)
                            .onChange(of: heightFeet) { _, _ in updateProfile() }
                            .onChange(of: heightInches) { _, _ in updateProfile() }
                            Text("(\(String(format: "%.0f", (Double(heightFeet * 12 + heightInches) * 2.54))) cm)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .accessibilityIdentifier("DataInput.HeightValue")
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Weight")
                                .font(.headline)
                                .accessibilityIdentifier("DataInput.WeightTitle")
                            Slider(
                                value: $weightPounds,
                                in: 50...500,
                                step: 1
                            ) {
                                Text("Weight")
                            } minimumValueLabel: {
                                Text("50 lbs")
                            } maximumValueLabel: {
                                Text("500 lbs")
                            }
                            .accessibilityIdentifier("DataInput.WeightSlider")
                            Text("\(Int(weightPounds)) lbs (\(String(format: "%.0f", weightPounds * 0.453592)) kg)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .accessibilityIdentifier("DataInput.WeightValue")
                                .onChange(of: weightPounds) { _, _ in updateProfile() }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Age")
                                .font(.headline)
                                .accessibilityIdentifier("DataInput.AgeTitle")
                            Slider(
                                value: Binding(get: { Double(age) }, set: { age = Int($0) }),
                                in: 10...100,
                                step: 1
                            ) {
                                Text("Age")
                            } minimumValueLabel: {
                                Text("10")
                            } maximumValueLabel: {
                                Text("100")
                            }
                            .accessibilityIdentifier("DataInput.AgeSlider")
                            Text("\(age) years")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .accessibilityIdentifier("DataInput.AgeValue")
                                .onChange(of: age) { _, _ in updateProfile() }
                        }
                    }
                }

                Button(action: onComplete) {
                    Text("Continue")
                }
                .buttonStyle(CoachPrimaryButtonStyle())
                .disabled(!canContinue)
                .opacity(canContinue ? 1 : 0.6)
                .accessibilityIdentifier("DataInput.ContinueButton")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .accessibilityIdentifier("DataInputScreen")
        .accessibilityElement(children: .contain)
        .onAppear {
            if userHeight > 0 {
                let totalInches = userHeight / 2.54
                heightFeet = Int(totalInches / 12)
                heightInches = Int(totalInches.truncatingRemainder(dividingBy: 12))
            } else {
                heightFeet = 5
                heightInches = 8
            }

            if userWeight > 0 {
                weightPounds = userWeight * 2.20462
            } else {
                weightPounds = 150
            }

            if userAge > 0 {
                age = userAge
            } else {
                age = 25
            }

            updateProfile()
        }
    }

    private var canContinue: Bool {
        heightFeet > 0 && heightInches >= 0 && heightInches < 12 &&
        weightPounds >= 50 && weightPounds <= 500 && age >= 10 && age <= 100
    }

    private var hasExistingData: Bool {
        userHeight > 0 || userWeight > 0 || userAge > 0
    }

    private func updateProfile() {
        let totalInches = Double(heightFeet * 12 + heightInches)
        let heightInCm = totalInches * 2.54
        let weightInKg = weightPounds * 0.453592

        userHeight = heightInCm
        userWeight = weightInKg
        userAge = age
    }
}

#Preview {
    PersonalInfoStepView(
        onComplete: {}
    )
}
