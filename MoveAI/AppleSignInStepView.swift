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
        VStack(spacing: 20) {
            Spacer(minLength: 20)

            CoachCard(elevated: true) {
                VStack(spacing: 18) {
                    Image(systemName: "applelogo")
                        .font(.system(size: 54, weight: .semibold))
                        .foregroundColor(.primary)

                    VStack(spacing: 10) {
                        Text("Sign in with Apple")
                            .font(CoachTheme.Typography.cardTitle)

                        Text("Secure authentication using your Apple ID")
                            .font(CoachTheme.Typography.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            CoachCard {
                VStack(spacing: 12) {
                    SignInWithAppleButton(
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        },
                        onCompletion: { result in
                            handleSignInResult(result)
                        }
                    )
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .cornerRadius(10)
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

                    if let errorMessage = errorMessage {
                        VStack(spacing: 10) {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)

                            Button("Try Again") {
                                self.errorMessage = nil
                            }
                            .buttonStyle(CoachSecondaryButtonStyle())
                        }
                        .padding(.top, 4)
                    }
                }
            }

            Spacer(minLength: 20)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityIdentifier(AccessibilityID.Onboarding.signIn)
    }

    private func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        isSigningIn = true
        errorMessage = nil

        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                handleSignInError("Invalid credential type")
                return
            }

            let userIdentifier = appleIDCredential.user
            let email = appleIDCredential.email
            let fullName = appleIDCredential.fullName

            appleAuthManager.saveUserData(
                userIdentifier: userIdentifier,
                email: email,
                fullName: fullName
            )

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
