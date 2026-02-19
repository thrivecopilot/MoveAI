//
//  DraggableAnalysisSheet.swift
//  MoveAI
//
//  Apple Maps–style draggable sheet with three states: collapsed (handle-only),
//  medium (analysis default), and expanded (reading/study).
//  Requirements: docs/screens/video-review.md
//

import SwiftUI

/// Sheet presentation state. Video height is the complement of sheet height.
enum AnalysisSheetState: Int, CaseIterable {
    /// Handle only; always visible so user can drag up.
    case collapsed
    /// Score, rep summary, and top fixes (Overview-style).
    case medium
    /// Full content: all tabs, scrollable.
    case expanded

    /// Fraction of content area given to the sheet (0...1). Video gets (1 - fraction).
    var sheetFraction: Double {
        switch self {
        case .collapsed: return 0.0
        case .medium:   return 0.38  // Tab bar + score + rep summary
        case .expanded: return 0.88  // Maps-style almost full screen
        }
    }
}

/// Tab for the analysis sheet content.
enum AnalysisSheetTab: String, CaseIterable {
    case overview = "Overview"
    case issues   = "Issues"
    case notes    = "Notes"
}

// MARK: - Draggable Analysis Sheet

enum DragHandleMetrics {
    static let height: CGFloat = 4
    static let paddingTop: CGFloat = 10
    static let paddingBottom: CGFloat = 8
    /// Minimum height so the handle remains comfortably tappable and visible.
    static var minCollapsedHeight: CGFloat { height + paddingTop + paddingBottom }
}

struct DraggableAnalysisSheet<OverviewContent: View, IssuesContent: View, NotesContent: View>: View {

    @Binding var sheetState: AnalysisSheetState
    @Binding var selectedTab: AnalysisSheetTab
    /// Optional: parent can bind to read current drag offset for layout (e.g. video height).
    @Binding var dragOffset: CGFloat
    @Binding var minCollapsedHeight: CGFloat
    let currentHeight: CGFloat
    let detentHeights: [AnalysisSheetState: CGFloat]
    let maxUp: CGFloat
    let maxDown: CGFloat

    let overviewContent: () -> OverviewContent
    let issuesContent: () -> IssuesContent
    let notesContent: () -> NotesContent

    @GestureState private var isDragging = false

    /// Slightly smaller radius in collapsed state while keeping original visual rhythm.
    private var sheetCornerRadius: CGFloat { sheetState == .collapsed ? 12 : 20 }
    private var collapsedRowHeight: CGFloat { minCollapsedHeight > 0 ? minCollapsedHeight : DragHandleMetrics.minCollapsedHeight }

    private let dragHandleHeight: CGFloat = DragHandleMetrics.height
    private let dragHandlePaddingTop: CGFloat = DragHandleMetrics.paddingTop
    private let dragHandlePaddingBottom: CGFloat = DragHandleMetrics.paddingBottom

    private let sheetBackground = Color(red: 0.06, green: 0.08, blue: 0.11)
    private let sheetSurface = Color(red: 0.09, green: 0.12, blue: 0.17)
    private let sheetStroke = Color.white.opacity(0.08)
    private let handleShadow = Color.black.opacity(0.35)
    private let accentColor = Color(red: 0.24, green: 0.86, blue: 1.0)

    init(
        sheetState: Binding<AnalysisSheetState>,
        selectedTab: Binding<AnalysisSheetTab>,
        dragOffset: Binding<CGFloat> = .constant(0),
        minCollapsedHeight: Binding<CGFloat> = .constant(0),
        currentHeight: CGFloat = 0,
        detentHeights: [AnalysisSheetState: CGFloat] = [:],
        maxUp: CGFloat = -240,
        maxDown: CGFloat = 240,
        @ViewBuilder overviewContent: @escaping () -> OverviewContent,
        @ViewBuilder issuesContent: @escaping () -> IssuesContent,
        @ViewBuilder notesContent: @escaping () -> NotesContent
    ) {
        self._sheetState = sheetState
        self._selectedTab = selectedTab
        self._dragOffset = dragOffset
        self._minCollapsedHeight = minCollapsedHeight
        self.currentHeight = currentHeight
        self.detentHeights = detentHeights
        self.maxUp = maxUp
        self.maxDown = maxDown
        self.overviewContent = overviewContent
        self.issuesContent = issuesContent
        self.notesContent = notesContent
    }

    var body: some View {
        VStack(spacing: 0) {
            dragHandle
            if sheetState == .medium || sheetState == .expanded {
                tabBar

                if sheetState == .expanded {
                    sheetContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                } else {
                    sheetContent
                        .frame(maxWidth: .infinity, alignment: .top)
                        .clipped()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(isDragging ? sheetBackground.opacity(1.0) : sheetBackground)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(sheetStroke)
                .frame(height: 1)
        }
        .cornerRadius(sheetCornerRadius, corners: [.topLeft, .topRight])
        .shadow(
            color: .black.opacity(sheetState == .collapsed ? 0.0 : 0.25),
            radius: sheetState == .collapsed ? 0 : 6,
            x: 0,
            y: -2
        )
        .gesture(
            DragGesture()
                .updating($isDragging) { _, state, _ in state = true }
                .onChanged { value in
                    let translation = value.translation.height
                    dragOffset = rubberBand(translation, min: maxUp, max: maxDown)
                }
                .onEnded { value in
                    let nextState = resolvedDetent(
                        translation: value.translation.height,
                        predictedTranslation: value.predictedEndTranslation.height
                    )
                    withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.85, blendDuration: 0.15)) {
                        sheetState = nextState
                        dragOffset = 0
                    }
                }
        )
        .onChange(of: sheetState) { _, newValue in
            if newValue != .expanded, selectedTab != .overview {
                selectedTab = .overview
            }
        }
    }

    /// Thin horizontal grabber (Apple Maps-style); no label.
    private var dragHandle: some View {
        let rowHeight = collapsedRowHeight

        return RoundedRectangle(cornerRadius: 2.5)
            .fill(Color.white.opacity(0.35))
            .frame(width: 44, height: dragHandleHeight)
            .padding(.top, dragHandlePaddingTop)
            .padding(.bottom, dragHandlePaddingBottom)
            .frame(maxWidth: .infinity)
            .frame(height: rowHeight, alignment: .center)
            .background(
                ZStack {
                    Rectangle()
                        .fill(sheetBackground)
                    if sheetState != .collapsed {
                        LinearGradient(
                            colors: [handleShadow, Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 10)
                        .frame(maxHeight: .infinity, alignment: .top)
                    }
                }
            )
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: DragHandleHeightKey.self, value: proxy.size.height)
                }
            )
            .onPreferenceChange(DragHandleHeightKey.self) { newValue in
                if newValue > 0 {
                    minCollapsedHeight = newValue
                }
            }
            .onAppear {
                if minCollapsedHeight <= 0 {
                    minCollapsedHeight = DragHandleMetrics.minCollapsedHeight
                }
            }
            .accessibilityIdentifier(AccessibilityID.Tabs.dragHandle)
            .onTapGesture {
                if sheetState == .collapsed {
                    withAnimation(.interactiveSpring()) {
                        sheetState = .medium
                    }
                }
            }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(AnalysisSheetTab.allCases, id: \.self) { tab in
                let canSelectTab = sheetState == .expanded || tab == .overview
                Button {
                    guard canSelectTab else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.subheadline)
                        .fontWeight(selectedTab == tab ? .semibold : .regular)
                        .foregroundColor(selectedTab == tab ? accentColor : Color.white.opacity(canSelectTab ? 0.65 : 0.35))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .disabled(!canSelectTab)
                .accessibilityIdentifier("Tab.\(tab.rawValue)")
            }
        }
        .background(sheetSurface)
    }

    @ViewBuilder
    private var sheetContent: some View {
        if sheetState == .medium {
            overviewContent()
        } else {
            switch selectedTab {
            case .overview:
                overviewContent()
            case .issues:
                issuesContent()
            case .notes:
                notesContent()
            }
        }
    }

    private func rubberBand(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        if value < min {
            let excess = value - min
            return min + excess * 0.2
        }
        if value > max {
            let excess = value - max
            return max + excess * 0.2
        }
        return value
    }

    private func nearestDetent(for height: CGFloat) -> AnalysisSheetState? {
        let candidates = detentHeights
            .filter { $0.value > 0 }
            .sorted { abs($0.value - height) < abs($1.value - height) }
        return candidates.first?.key
    }

    private func detentAbove(_ state: AnalysisSheetState) -> AnalysisSheetState {
        switch state {
        case .collapsed:
            return .medium
        case .medium:
            return .expanded
        case .expanded:
            return .expanded
        }
    }

    private func detentBelow(_ state: AnalysisSheetState) -> AnalysisSheetState {
        switch state {
        case .collapsed:
            return .collapsed
        case .medium:
            return .collapsed
        case .expanded:
            return .medium
        }
    }

    private func resolvedDetent(translation: CGFloat, predictedTranslation: CGFloat) -> AnalysisSheetState {
        // Step between adjacent detents for predictable snapping and to avoid skipping medium.
        let dominantTranslation = abs(predictedTranslation) > abs(translation) ? predictedTranslation : translation
        let threshold: CGFloat = 72

        if dominantTranslation <= -threshold {
            return detentAbove(sheetState)
        }

        if dominantTranslation >= threshold {
            return detentBelow(sheetState)
        }

        let targetHeight = max(0, currentHeight - translation)
        return nearestDetent(for: targetHeight) ?? sheetState
    }
}

// MARK: - Corner Radius Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCornerShape(radius: radius, corners: corners))
    }
}

struct RoundedCornerShape: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

private struct DragHandleHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var sheetState: AnalysisSheetState = .medium
        @State private var selectedTab: AnalysisSheetTab = .overview
        @State private var dragOffset: CGFloat = 0

        var body: some View {
            DraggableAnalysisSheet(
                sheetState: $sheetState,
                selectedTab: $selectedTab,
                dragOffset: $dragOffset,
                overviewContent: {
                    Text("Overview content")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                },
                issuesContent: {
                    Text("Issues content")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                },
                notesContent: {
                    Text("Notes content")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            )
        }
    }
    return PreviewWrapper()
}
