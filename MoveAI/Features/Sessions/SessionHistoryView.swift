//
//  SessionHistoryView.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//  Requirements: docs/screens/video-review.md
//

import SwiftUI
import AVFoundation

struct SessionHistoryView: View {
    @ObservedObject var sessionManager: SessionManager
    @State private var selectedMovement: MovementType?
    let errorMessage: String?
    let notesLineLimit: Int?

    init(sessionManager: SessionManager) {
        self.sessionManager = sessionManager
        self.errorMessage = nil
        self.notesLineLimit = 1
    }

    init(sessionManager: SessionManager, errorMessage: String? = nil, notesLineLimit: Int? = 1) {
        self.sessionManager = sessionManager
        self.errorMessage = errorMessage
        self.notesLineLimit = notesLineLimit
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: CoachTheme.Surfaces.groupSpacing) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: CoachTheme.Surfaces.groupSpacing) {
                        FilterButton(
                            title: "All",
                            isSelected: selectedMovement == nil,
                            action: { selectedMovement = nil }
                        )

                        ForEach(MovementType.allCases) { movement in
                            FilterButton(
                                title: movement.displayName,
                                isSelected: selectedMovement == movement,
                                action: { selectedMovement = movement }
                            )
                        }
                    }
                    .padding(.horizontal, CoachTheme.Surfaces.screenHorizontalPadding)
                }
                .padding(.top, 8)

                if let errorMessage = errorMessage {
                    errorStateView(errorMessage)
                } else if filteredSessions.isEmpty {
                    emptyStateView
                } else {
                    sessionsList
                }
            }
            .navigationTitle("Session History")
            .navigationBarTitleDisplayMode(.large)
            .coachNavigationChrome()
            .coachScreenContainer()
            .accessibilityIdentifier(AccessibilityID.SessionHistory.root)
        }
    }

    private var filteredSessions: [Session] {
        if let selectedMovement = selectedMovement {
            return sessionManager.sessionsForMovement(selectedMovement)
        } else {
            return sessionManager.sessions.sorted { $0.timestamp > $1.timestamp }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: CoachTheme.Surfaces.sectionSpacing) {
            Spacer()

            CoachCard {
                VStack(spacing: CoachTheme.Surfaces.sectionSpacing) {
                    Image(systemName: "video.fill")
                        .font(.system(size: 56))
                        .foregroundColor(.secondary)

                    Text("No Sessions Yet")
                        .font(CoachTheme.Typography.title)

                    Text("Start recording your movements to see your progress here")
                        .font(CoachTheme.Typography.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, CoachTheme.Surfaces.screenHorizontalPadding)

            Spacer()
        }
        .accessibilityIdentifier(AccessibilityID.SessionHistory.emptyState)
        .accessibilityElement(children: .contain)
    }

    private var sessionsList: some View {
        ScrollView {
            LazyVStack(spacing: CoachTheme.Surfaces.groupSpacing) {
                Text("")
                    .frame(height: 0)
                    .accessibilityHidden(false)
                    .accessibilityIdentifier(AccessibilityID.SessionHistory.list)

                ForEach(filteredSessions) { session in
                    NavigationLink(destination: SessionDetailView(session: session, sessionManager: sessionManager, onExit: nil)) {
                        SessionCard(session: session, notesLineLimit: notesLineLimit)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, CoachTheme.Surfaces.screenHorizontalPadding)
            .padding(.vertical, CoachTheme.Surfaces.rowVerticalPadding)
        }
    }

    private func errorStateView(_ message: String) -> some View {
        VStack(spacing: CoachTheme.Surfaces.sectionSpacing) {
            Spacer()

            CoachCard {
                VStack(spacing: CoachTheme.Surfaces.groupSpacing) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)

                    Text("Unable to Load Sessions")
                        .font(CoachTheme.Typography.title)

                    Text(message)
                        .font(CoachTheme.Typography.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button("Try Again") {
                        // Placeholder for real retry action in production flows.
                    }
                    .buttonStyle(CoachPrimaryButtonStyle())
                    .accessibilityIdentifier(AccessibilityID.SessionHistory.tryAgainButton)
                }
            }
            .padding(.horizontal, CoachTheme.Surfaces.screenHorizontalPadding)

            Spacer()
        }
        .accessibilityIdentifier(AccessibilityID.SessionHistory.errorState)
        .accessibilityElement(children: .contain)
    }
}

struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            CoachChip(
                title: title,
                tint: isSelected ? CoachTheme.Palette.accent : .secondary
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("\(AccessibilityID.SessionHistory.filterButton).\(title)")
    }
}

struct SessionCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let session: Session
    let notesLineLimit: Int?

    var body: some View {
        HStack(spacing: CoachTheme.Surfaces.sectionSpacing) {
            Image(systemName: session.movementType.icon)
                .font(.title2)
                .foregroundColor(CoachTheme.Palette.accent)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(session.displayName)
                    .font(CoachTheme.Typography.subtitle)
                    .foregroundColor(.primary)

                Text(session.formattedDate)
                    .font(CoachTheme.Typography.meta)
                    .foregroundColor(.secondary)

                if let notes = session.notes, !notes.isEmpty {
                    Text(notes)
                        .font(CoachTheme.Typography.meta)
                        .foregroundColor(.secondary)
                        .lineLimit(notesLineLimit)
                }
            }

            Spacer()

            if let score = session.score {
                VStack(spacing: 2) {
                    Text("\(Int(score))")
                        .font(.title3.weight(.bold))
                        .foregroundColor(scoreColor(Int(score)))

                    Text("Score")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, CoachTheme.Surfaces.rowHorizontalPadding)
                .padding(.vertical, CoachTheme.Surfaces.rowVerticalPadding)
                .background(CoachTheme.Palette.secondarySurface(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: CoachTheme.Surfaces.rowCornerRadius, style: .continuous))
            } else {
                VStack(spacing: 2) {
                    Image(systemName: "clock")
                        .font(.title3)
                        .foregroundColor(.orange)

                    Text("Pending")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, CoachTheme.Surfaces.rowHorizontalPadding)
                .padding(.vertical, CoachTheme.Surfaces.rowVerticalPadding)
                .background(CoachTheme.Palette.secondarySurface(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: CoachTheme.Surfaces.rowCornerRadius, style: .continuous))
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(CoachTheme.Surfaces.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: CoachTheme.Surfaces.rowCornerRadius, style: .continuous)
                .fill(CoachTheme.Palette.surfaceFill(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CoachTheme.Surfaces.rowCornerRadius, style: .continuous)
                .stroke(CoachTheme.Palette.stroke(for: colorScheme), lineWidth: 1)
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.18 : 0.06), radius: 8, x: 0, y: 4)
        .accessibilityIdentifier("\(AccessibilityID.SessionHistory.sessionCard).\(session.id.uuidString)")
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 80 {
            return .green
        } else if score >= 60 {
            return .orange
        } else {
            return .red
        }
    }
}

struct SessionDetailView: View {
    let session: Session
    @ObservedObject var sessionManager: SessionManager
    let onExit: (() -> Void)?

    var body: some View {
        let currentSession = sessionManager.sessions.first(where: { $0.id == session.id }) ?? session
        VideoReviewLayoutView(
            session: currentSession,
            sessionManager: sessionManager,
            onExit: onExit
        )
    }
}

#Preview {
    SessionHistoryView(sessionManager: SessionManager())
        .environmentObject(TabBarVisibility())
}

#if DEBUG
#Preview("Session detail (standalone)") {
    SessionDetailView(
        session: PreviewData.sessionWithAnalysis(),
        sessionManager: SessionManager(),
        onExit: nil
    )
    .environmentObject(TabBarVisibility())
}
#endif
