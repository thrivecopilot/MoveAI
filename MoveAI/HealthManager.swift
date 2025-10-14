//
//  HealthManager.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import Foundation
import HealthKit

@MainActor
class HealthManager: ObservableObject {
    @Published var hasPermissions = false
    @Published var isAvailable = false
    
    private let healthStore = HKHealthStore()
    
    // Define the health data types we want to read
    private let typesToRead: Set<HKObjectType> = [
        HKObjectType.workoutType(),
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.quantityType(forIdentifier: .height)!,
        HKObjectType.quantityType(forIdentifier: .bodyMass)!,
        HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!
    ]
    
    init() {
        isAvailable = HKHealthStore.isHealthDataAvailable()
        checkPermissions()
    }
    
    // MARK: - Public Methods
    
    func requestPermissions() async throws -> Bool {
        guard isAvailable else {
            throw HealthError.notAvailable
        }
        
        // Request authorization - this shows the dialog
        try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
        
        // Instead of relying on timing, check if we can actually read data
        // This is more reliable than checking authorization status
        return await canReadHealthData()
    }
    
    private func canReadHealthData() async -> Bool {
        // Try to read a simple piece of data to verify permissions
        // This is more reliable than checking authorization status
        let heightType = HKObjectType.quantityType(forIdentifier: .height)!
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heightType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, error in
                // If we get here without an authorization error, we have permissions
                // Even if there's no data, the query succeeded means we have access
                let hasAccess = error == nil || (error as? HKError)?.code != .errorAuthorizationDenied
                continuation.resume(returning: hasAccess)
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - Private Methods
    
    private func checkPermissions() {
        guard isAvailable else {
            hasPermissions = false
            return
        }
        
        // Check authorization status for each type
        let workoutStatus = healthStore.authorizationStatus(for: HKObjectType.workoutType())
        let heartRateStatus = healthStore.authorizationStatus(for: HKObjectType.quantityType(forIdentifier: .heartRate)!)
        let heightStatus = healthStore.authorizationStatus(for: HKObjectType.quantityType(forIdentifier: .height)!)
        let weightStatus = healthStore.authorizationStatus(for: HKObjectType.quantityType(forIdentifier: .bodyMass)!)
        let dateOfBirthStatus = healthStore.authorizationStatus(for: HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!)
        
        // Debug logging to help troubleshoot permission issues
        print("HealthKit Permission Status:")
        print("  Workout: \(workoutStatus.rawValue) (\(workoutStatus))")
        print("  Heart Rate: \(heartRateStatus.rawValue) (\(heartRateStatus))")
        print("  Height: \(heightStatus.rawValue) (\(heightStatus))")
        print("  Weight: \(weightStatus.rawValue) (\(weightStatus))")
        print("  Date of Birth: \(dateOfBirthStatus.rawValue) (\(dateOfBirthStatus))")
        
        // For read permissions, we need .sharingAuthorized status
        let hasWorkoutPermission = workoutStatus == .sharingAuthorized
        let hasHeartRatePermission = heartRateStatus == .sharingAuthorized
        let hasHeightPermission = heightStatus == .sharingAuthorized
        let hasWeightPermission = weightStatus == .sharingAuthorized
        let hasDateOfBirthPermission = dateOfBirthStatus == .sharingAuthorized
        
        // Consider permissions granted if we have access to ALL of the data types
        // This ensures we have complete health data access
        hasPermissions = hasWorkoutPermission && hasHeartRatePermission && hasHeightPermission && hasWeightPermission && hasDateOfBirthPermission
        
        // Additional debugging for edge cases
        let allNotDetermined = workoutStatus == .notDetermined && 
                              heartRateStatus == .notDetermined && 
                              heightStatus == .notDetermined && 
                              weightStatus == .notDetermined && 
                              dateOfBirthStatus == .notDetermined
        
        if allNotDetermined {
            print("All permissions are .notDetermined - user may have dismissed the dialog without responding")
        }
        
        // Check for denied permissions
        let anyDenied = workoutStatus == .sharingDenied || 
                       heartRateStatus == .sharingDenied || 
                       heightStatus == .sharingDenied || 
                       weightStatus == .sharingDenied || 
                       dateOfBirthStatus == .sharingDenied
        
        if anyDenied {
            print("Some permissions were denied by the user")
        }
        
        print("  Overall: \(hasPermissions)")
    }
}

// MARK: - Error Types

enum HealthError: LocalizedError {
    case notAvailable
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        }
    }
}
