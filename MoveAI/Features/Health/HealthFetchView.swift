//
//  HealthFetchView.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import SwiftUI

struct HealthFetchView: View {
    let state: HealthFetchState
    let onAction: (HealthAction) -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 24) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)
                
                VStack(spacing: 16) {
                    Text("Fetching Your Health Data")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Retrieving your height, weight, and age from Apple Health")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            Spacer()
            
            VStack(spacing: 16) {
                if state.isLoading {
                    ProgressView()
                        .scaleEffect(1.2)
                    
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if state.isFailed {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title2)
                            .foregroundColor(.orange)
                        
                        Text(state.errorMessage ?? "Failed to fetch health data")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Try Again") {
                            onAction(.healthProfileRequested)
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
        .onAppear {
            if case .idle = state {
                onAction(.healthProfileRequested)
            }
        }
    }
}

#Preview {
    HealthFetchView(
        state: .loading,
        onAction: { _ in }
    )
}

