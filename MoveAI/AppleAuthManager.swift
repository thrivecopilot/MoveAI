//
//  AppleAuthManager.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import Foundation
import AuthenticationServices
import Security

@MainActor
class AppleAuthManager: ObservableObject {
    @Published var isSignedIn = false
    @Published var currentUser: AppleUser?
    
    private let keychain = KeychainHelper()
    private let userIdentifierKey = "apple_user_identifier"
    private let userEmailKey = "apple_user_email"
    private let userFullNameKey = "apple_user_full_name"
    
    init() {
        loadStoredUser()
    }
    
    // MARK: - Public Methods
    
    func saveUserData(
        userIdentifier: String,
        email: String?,
        fullName: PersonNameComponents?
    ) {
        // Store user identifier (required for future sign-ins)
        keychain.save(userIdentifier, forKey: userIdentifierKey)
        
        // Store email if provided (only available on first sign-in)
        if let email = email {
            keychain.save(email, forKey: userEmailKey)
        }
        
        // Store full name if provided (only available on first sign-in)
        if let fullName = fullName {
            let formatter = PersonNameComponentsFormatter()
            let fullNameString = formatter.string(from: fullName)
            keychain.save(fullNameString, forKey: userFullNameKey)
        }
        
        // Create user object
        currentUser = AppleUser(
            identifier: userIdentifier,
            email: email,
            fullName: fullName
        )
        
        isSignedIn = true
    }
    
    func signOut() {
        // Clear stored data
        keychain.delete(forKey: userIdentifierKey)
        keychain.delete(forKey: userEmailKey)
        keychain.delete(forKey: userFullNameKey)
        
        // Reset state
        currentUser = nil
        isSignedIn = false
    }
    
    // MARK: - Private Methods
    
    private func loadStoredUser() {
        guard let identifier = keychain.load(forKey: userIdentifierKey),
              !identifier.isEmpty else {
            return
        }
        
        let email = keychain.load(forKey: userEmailKey)
        let fullNameString = keychain.load(forKey: userFullNameKey)
        
        // Reconstruct PersonNameComponents from stored string
        var fullName: PersonNameComponents?
        if let fullNameString = fullNameString {
            let formatter = PersonNameComponentsFormatter()
            fullName = formatter.personNameComponents(from: fullNameString)
        }
        
        currentUser = AppleUser(
            identifier: identifier,
            email: email,
            fullName: fullName
        )
        
        isSignedIn = true
    }
}

// MARK: - Supporting Types

struct AppleUser {
    let identifier: String
    let email: String?
    let fullName: PersonNameComponents?
    
    var displayName: String {
        if let fullName = fullName {
            let formatter = PersonNameComponentsFormatter()
            return formatter.string(from: fullName)
        }
        return email ?? "User"
    }
}

