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
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 24) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                VStack(spacing: 16) {
                    Text("Review Your Information")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(hasExistingData ? "Your information was synced from Apple Health. You can edit it below if needed." : "This helps us personalize your movement analysis")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            Spacer()
            
            VStack(spacing: 20) {
                // Height Input
                VStack(alignment: .leading) {
                    Text("Height")
                        .font(.headline)
                    HStack {
                        Picker("Feet", selection: $heightFeet) {
                            ForEach(0..<9) { feet in
                                Text("\(feet) ft").tag(feet)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 100, height: 120)
                        .clipped()

                        Picker("Inches", selection: $heightInches) {
                            ForEach(0..<12) { inches in
                                Text("\(inches) in").tag(inches)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 100, height: 120)
                        .clipped()
                    }
                    .padding(.horizontal)
                    .onChange(of: heightFeet) { _, _ in updateProfile() }
                    .onChange(of: heightInches) { _, _ in updateProfile() }
                    Text("(\(String(format: "%.0f", (Double(heightFeet * 12 + heightInches) * 2.54))) cm)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Weight Input
                VStack(alignment: .leading) {
                    Text("Weight")
                        .font(.headline)
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
                    Text("\(Int(weightPounds)) lbs (\(String(format: "%.0f", weightPounds * 0.453592)) kg)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    .onChange(of: weightPounds) { _, _ in updateProfile() }
                }

                // Age Input
                VStack(alignment: .leading) {
                    Text("Age")
                        .font(.headline)
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
                    Text("\(age) years")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    .onChange(of: age) { _, _ in updateProfile() }
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Continue button
            Button(action: onComplete) {
                Text("Continue")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(canContinue ? Color.accentColor : Color.gray)
                    .cornerRadius(8)
            }
            .disabled(!canContinue)
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
        .onAppear {
            // Load existing values from AppStorage or use defaults
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
        return heightFeet > 0 && heightInches >= 0 && heightInches < 12 &&
               weightPounds >= 50 && weightPounds <= 500 && age >= 10 && age <= 100
    }
    
    private var hasExistingData: Bool {
        return userHeight > 0 || userWeight > 0 || userAge > 0
    }
    
    private func updateProfile() {
        // Convert feet and inches to centimeters
        let totalInches = Double(heightFeet * 12 + heightInches)
        let heightInCm = totalInches * 2.54
        
        // Convert pounds to kilograms
        let weightInKg = weightPounds * 0.453592
        
        // Save to AppStorage for persistence
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
