//
//  HealthService.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import Foundation
import HealthKit

protocol HealthServiceProtocol {
    func fetchProfile() async throws -> HealthProfile
}

class HealthService: HealthServiceProtocol {
    private let healthStore = HKHealthStore()
    
    func fetchProfile() async throws -> HealthProfile {
        // Check if HealthKit is available
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthServiceError.notAvailable
        }
        
        // Check if we have permissions
        let heightType = HKObjectType.quantityType(forIdentifier: .height)!
        let weightType = HKObjectType.quantityType(forIdentifier: .bodyMass)!
        let dateOfBirthType = HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!
        
        let heightStatus = healthStore.authorizationStatus(for: heightType)
        let weightStatus = healthStore.authorizationStatus(for: weightType)
        let dateOfBirthStatus = healthStore.authorizationStatus(for: dateOfBirthType)
        
        // If we don't have permissions, throw error
        if heightStatus != .sharingAuthorized || 
           weightStatus != .sharingAuthorized || 
           dateOfBirthStatus != .sharingAuthorized {
            throw HealthServiceError.permissionsNotGranted
        }
        
        // Fetch height
        let height = try await fetchHeight()
        
        // Fetch weight
        let weight = try await fetchWeight()
        
        // Fetch age
        let age = try await fetchAge()
        
        return HealthProfile(
            heightFeet: height.feet,
            heightInches: height.inches,
            weightLbs: weight,
            age: age
        )
    }
    
    private func fetchHeight() async throws -> (feet: Int, inches: Int) {
        let heightType = HKObjectType.quantityType(forIdentifier: .height)!
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heightType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let sample = samples?.first as? HKQuantitySample else {
                    // No height data available, use demo data
                    continuation.resume(returning: (feet: 5, inches: 9))
                    return
                }
                
                // Convert to inches
                let heightInInches = sample.quantity.doubleValue(for: HKUnit.inch())
                let feet = Int(heightInInches / 12)
                let inches = Int(heightInInches.truncatingRemainder(dividingBy: 12))
                
                continuation.resume(returning: (feet: feet, inches: inches))
            }
            
            healthStore.execute(query)
        }
    }
    
    private func fetchWeight() async throws -> Int {
        let weightType = HKObjectType.quantityType(forIdentifier: .bodyMass)!
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: weightType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let sample = samples?.first as? HKQuantitySample else {
                    // No weight data available, use demo data
                    continuation.resume(returning: 155)
                    return
                }
                
                // Convert to pounds
                let weightInPounds = sample.quantity.doubleValue(for: HKUnit.pound())
                
                continuation.resume(returning: Int(weightInPounds))
            }
            
            healthStore.execute(query)
        }
    }
    
    private func fetchAge() async throws -> Int {
        return try await withCheckedThrowingContinuation { continuation in
            do {
                let dateOfBirthComponents = try healthStore.dateOfBirthComponents()
                
                guard let birthYear = dateOfBirthComponents.year else {
                    // No date of birth available, use demo data
                    continuation.resume(returning: 30)
                    return
                }
                
                let currentYear = Calendar.current.component(.year, from: Date())
                let age = currentYear - birthYear
                
                continuation.resume(returning: age)
            } catch {
                // No date of birth available, use demo data
                continuation.resume(returning: 30)
            }
        }
    }
}

// MARK: - Demo Service for Simulator
class DemoHealthService: HealthServiceProtocol {
    func fetchProfile() async throws -> HealthProfile {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        return HealthProfile.demo
    }
}

// MARK: - Error Types
enum HealthServiceError: LocalizedError {
    case notAvailable
    case permissionsNotGranted
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        case .permissionsNotGranted:
            return "HealthKit permissions not granted"
        }
    }
}
