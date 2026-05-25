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

    // MARK: - Cue Overlay
    enum CueOverlay {
        static let root = "CueOverlayView"
        static let title = "CueOverlay.Title"
        static let quickFix = "CueOverlay.QuickFix"
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
        static let powerliftingLayoutProbe = "Home.Powerlifting.LayoutProbe"
        static let movementOption = "Home.Movement"
        static let recentSessions = "Home.RecentSessions"
        static let viewAllButton = "Home.ViewAll"
    }

    // MARK: - Profile
    enum Profile {
        static let root = "ProfileView"
        static let header = "Profile.Header"
        static let healthCard = "Profile.HealthCard"
        static let quickStatsCard = "Profile.QuickStatsCard"
        static let settingsCard = "Profile.SettingsCard"
    }

    // MARK: - Movement Selection
    enum MovementSelection {
        static let root = "MovementSelectionView"
        static let modePicker = "MovementSelection.ModePicker"
        static let grid = "MovementSelection.Grid"
        static let card = "MovementSelection.Card"
    }

    // MARK: - Onboarding
    enum Onboarding {
        static let root = "OnboardingFlow"
        static let progress = "Onboarding.Progress"
        static let welcome = "Onboarding.Welcome"
        static let signIn = "Onboarding.SignIn"
        static let health = "Onboarding.Health"
        static let personalInfo = "Onboarding.PersonalInfo"
    }

    // MARK: - Trends
    enum Trends {
        static let root = "TrendsView"
        static let filterMovement = "Trends.Filter.Movement"
        static let primaryFixCard = "Trends.PrimaryFixCard"
        static let primaryFixActionFixIt = "Trends.PrimaryFix.Action.FixIt"
        static let primaryFixActionWatchExamples = "Trends.PrimaryFix.Action.WatchExamples"
        static let primaryFixActionTrackWorkout = "Trends.PrimaryFix.Action.TrackWorkout"
        static let todayCue = "Trends.TodayCue"
        static let qualitySummary = "Trends.QualitySummary"
        static let qualityDimension = "Trends.Quality.Dimension"
        static let fixCard = "Trends.FixCard"
        static let quickRoutine = "Trends.QuickRoutine"
        static let quickRoutineStart = "Trends.QuickRoutine.Start"
        static let expertSection = "Trends.ExpertSection"
        static let expertCard = "Trends.ExpertCard"
        static let progressNarrative = "Trends.ProgressNarrative"
        static let smallWins = "Trends.SmallWins"

        // Legacy IDs retained for backward compatibility.
        static let focusCard = "Trends.FocusCard"
        static let progressCard = "Trends.ProgressCard"
        static let troubleAreaList = "Trends.TroubleAreaList"
        static let recommendationCard = "Trends.RecommendationCard"
        static let whatImproved = "Trends.WhatImproved"
    }

    // MARK: - Main Tab Bar
    enum MainTabBar {
        static let root = "MainTabBar"
        static let button = "MainTabBar.Button"
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
