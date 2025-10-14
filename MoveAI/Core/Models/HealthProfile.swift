//
//  HealthProfile.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import Foundation

struct HealthProfile: Equatable {
    let heightFeet: Int
    let heightInches: Int
    let weightLbs: Int
    let age: Int
    
    init(heightFeet: Int = 0, heightInches: Int = 0, weightLbs: Int = 0, age: Int = 0) {
        self.heightFeet = heightFeet
        self.heightInches = heightInches
        self.weightLbs = weightLbs
        self.age = age
    }
    
    var heightInCm: Double {
        let totalInches = Double(heightFeet * 12 + heightInches)
        return totalInches * 2.54
    }
    
    var weightInKg: Double {
        return Double(weightLbs) * 0.453592
    }
    
    var displayHeight: String {
        return "\(heightFeet)'\(heightInches)\""
    }
    
    var displayWeight: String {
        return "\(weightLbs) lbs"
    }
    
    var displayAge: String {
        return "\(age) years"
    }
    
    var isValid: Bool {
        return heightFeet > 0 && heightInches >= 0 && heightInches < 12 &&
               weightLbs > 0 && age > 0
    }
}

// MARK: - Demo Data for Simulator
extension HealthProfile {
    static let demo = HealthProfile(
        heightFeet: 5,
        heightInches: 9,
        weightLbs: 155,
        age: 30
    )
}

