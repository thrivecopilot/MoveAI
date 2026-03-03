//
//  AccessibilityID.swift
//  MoveAI
//
//  Centralized accessibility identifier constants.
//  Use these in views via .accessibilityIdentifier(AccessibilityID.Screen.element)
//  and in UI tests via the mirrored AID enum in MoveAIUITests/Helpers/AID.swift.
//
//  IMPORTANT: Keep this file in sync with AID.swift (test target mirror).
//  When adding a new identifier here, also add it to AID.swift.
//

import Foundation

enum AccessibilityID {
    // MARK: - Session History
    enum SessionHistory {
        static let root = "SessionHistoryView"
        static let emptyState = "SessionHistoryEmptyState"
        static let list = "SessionHistoryList"
        static let errorState = "SessionHistoryErrorState"
        static let filterButton = "SessionHistory.Filter"       // append ".\(title)"
        static let sessionCard = "SessionHistory.Card"           // append ".\(id)"
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
        static let issueCard = "Issues.Card"                    // append ".\(id)"
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
        static let movementOption = "Home.Movement"              // append ".\(type)"
        static let recentSessions = "Home.RecentSessions"
        static let viewAllButton = "Home.ViewAll"
    }

    // MARK: - Main Tab Bar
    enum MainTabBar {
        static let root = "MainTabBar"
        static let button = "MainTabBar.Button"              // append ".\(tab)"
    }

    // MARK: - Sheet Tabs
    enum Tabs {
        static let overview = "Tab.Overview"
        static let issues = "Tab.Issues"
        static let notes = "Tab.Notes"
        static let dragHandle = "VideoReview.DragHandle"
    }
}
