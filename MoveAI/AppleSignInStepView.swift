//
//  AppleSignInStepView.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import SwiftUI
import AuthenticationServices

struct AppleSignInStepView: View {
    @ObservedObject var appleAuthManager: AppleAuthManager
    let onSignInSuccess: () -> Void
    
    @State private var isSigningIn = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 24) {
                Image(systemName: "applelogo")
                    .font(.system(size: 60))
                    .foregroundColor(.primary)
                
                VStack(spacing: 16) {
                    Text("Sign in with Apple")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Secure authentication using your Apple ID")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            Spacer()
            
            VStack(spacing: 16) {
                // Sign in with Apple button
                SignInWithAppleButton(
                    onRequest: { request in
                        // Configure the request
                        request.requestedScopes = [.fullName, .email]
                    },
                    onCompletion: { result in
                        handleSignInResult(result)
                    }
                )
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .cornerRadius(8)
                .disabled(isSigningIn)
                
                if isSigningIn {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Signing in...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Error message with retry
                if let errorMessage = errorMessage {
                    VStack(spacing: 12) {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                        
                        Button("Try Again") {
                            self.errorMessage = nil
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
    
    private func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        isSigningIn = true
        errorMessage = nil
        
        switch result {
        case .success(let authorization):
            // Extract Apple ID credential
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                handleSignInError("Invalid credential type")
                return
            }
            
            // Store user identifier and other data
            let userIdentifier = appleIDCredential.user
            let email = appleIDCredential.email
            let fullName = appleIDCredential.fullName
            
            // Save to Keychain using our AppleAuthManager
            appleAuthManager.saveUserData(
                userIdentifier: userIdentifier,
                email: email,
                fullName: fullName
            )
            
            // Success - notify parent
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isSigningIn = false
                onSignInSuccess()
            }
            
        case .failure(let error):
            handleSignInError(error.localizedDescription)
        }
    }
    
    private func handleSignInError(_ message: String) {
        DispatchQueue.main.async {
            isSigningIn = false
            errorMessage = message
        }
    }
}

#Preview {
    AppleSignInStepView(
        appleAuthManager: AppleAuthManager(),
        onSignInSuccess: {}
    )
}
