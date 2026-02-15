//
//  AID.swift
//  MoveAIUITests
//
//  Mirror of AccessibilityID.swift (app target) for use in UI tests.
//  UI test targets cannot import app code directly, so identifier strings
//  are duplicated here. Keep in sync with MoveAI/Support/AccessibilityID.swift.
//

import Foundation

/// Accessibility identifier constants for UI test queries.
/// Mirror of `AccessibilityID` in the app target.
enum AID {
    // MARK: - Session History
    enum SessionHistory {
        static let root = "SessionHistoryView"
        static let emptyState = "SessionHistoryEmptyState"
        static let list = "SessionHistoryList"
        static let errorState = "SessionHistoryErrorState"
        static let filterButton = "SessionHistory.Filter"
        static let sessionCard = "SessionHistory.Card"
        static let tryAgainButton = "SessionHistory.TryAgain"
    }

    // MARK: - Video Review
    enum VideoReview {
        static let root = "VideoReviewLayoutView"
        static let sheet = "VideoReviewSheet"
        static let closeButton = "VideoReview.Close"
        static let sessionTitle = "VideoReview.Title"
        static let playPauseButton = "VideoReview.PlayPause"
    }

    // MARK: - Overview Tab
    enum Overview {
        static let root = "OverviewTab"
        static let scoreValue = "Overview.ScoreValue"
        static let scoreLabel = "Overview.ScoreLabel"
        static let repSummary = "Overview.RepSummary"
        static let topFixes = "Overview.TopFixes"
    }

    // MARK: - Issues Tab
    enum Issues {
        static let root = "IssuesTab"
        static let emptyText = "Issues.Empty"
        static let issueCard = "Issues.Card"
    }

    // MARK: - Notes Tab
    enum Notes {
        static let root = "NotesTab"
        static let header = "Notes.Header"
        static let editButton = "Notes.EditButton"
        static let textField = "Notes.TextField"
        static let notesText = "Notes.Text"
    }

    // MARK: - Home
    enum Home {
        static let root = "HomeView"
        static let welcomeHeader = "Home.WelcomeHeader"
        static let startSessionSection = "Home.StartSession"
        static let powerliftingCard = "Home.Powerlifting"
        static let movementOption = "Home.Movement"
        static let recentSessions = "Home.RecentSessions"
        static let viewAllButton = "Home.ViewAll"
    }

    // MARK: - Sheet Tabs
    enum Tabs {
        static let overview = "Tab.Overview"
        static let issues = "Tab.Issues"
        static let notes = "Tab.Notes"
        static let dragHandle = "VideoReview.DragHandle"
    }

    /// Returns the ScenarioRoot identifier for a given scenario name.
    static func scenarioRoot(_ name: String) -> String {
        "ScenarioRoot_\(name)"
    }
}
