//
//  DraggableAnalysisSheet.swift
//  MoveAI
//
//  Apple Maps–style draggable sheet with three states: collapsed (video-first),
//  medium (analysis default), and expanded (reading/study).
//

import SwiftUI

/// Sheet presentation state. Video height is the complement of sheet height.
enum AnalysisSheetState: Int, CaseIterable {
    case hidden     // Handle only (video full height)
    case collapsed  // Video ~80%, sheet shows tab bar only
    case medium     // Video ~55%, sheet shows cards (default)
    case expanded   // Video ~20%, sheet shows full content
    
    /// Fraction of content area given to the sheet (0...1). Video gets (1 - fraction).
    var sheetFraction: Double {
        switch self {
        case .hidden:    return 0.0
        case .collapsed: return 0.20
        case .medium:   return 0.45
        case .expanded: return 0.80
        }
    }
    
    /// Next state when dragging up (expand).
    var nextUp: AnalysisSheetState? {
        switch self {
        case .hidden:    return .collapsed
        case .collapsed: return .medium
        case .medium:    return .expanded
        case .expanded:  return nil
        }
    }
    
    /// Next state when dragging down (collapse).
    var nextDown: AnalysisSheetState? {
        switch self {
        case .hidden:    return nil
        case .collapsed: return .hidden
        case .medium:    return .collapsed
        case .expanded:  return .medium
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

struct DraggableAnalysisSheet<OverviewContent: View, IssuesContent: View, NotesContent: View>: View {
    @Binding var sheetState: AnalysisSheetState
    @Binding var selectedTab: AnalysisSheetTab
    /// Optional: parent can bind to read current drag offset for layout (e.g. video height).
    @Binding var dragOffset: CGFloat
    let maxUp: CGFloat
    let maxDown: CGFloat
    
    let overviewContent: () -> OverviewContent
    let issuesContent: () -> IssuesContent
    let notesContent: () -> NotesContent
    
    @GestureState private var isDragging = false
    
    private let snapThreshold: CGFloat = 30
    private let dragHandleHeight: CGFloat = 24
    
    private let sheetBackground = Color(red: 0.06, green: 0.08, blue: 0.11)
    private let sheetSurface = Color(red: 0.09, green: 0.12, blue: 0.17)
    private let sheetStroke = Color.white.opacity(0.08)
    private let handleShadow = Color.black.opacity(0.35)
    private let accentColor = Color(red: 0.24, green: 0.86, blue: 1.0)
    
    init(
        sheetState: Binding<AnalysisSheetState>,
        selectedTab: Binding<AnalysisSheetTab>,
        dragOffset: Binding<CGFloat> = .constant(0),
        maxUp: CGFloat = -240,
        maxDown: CGFloat = 240,
        @ViewBuilder overviewContent: @escaping () -> OverviewContent,
        @ViewBuilder issuesContent: @escaping () -> IssuesContent,
        @ViewBuilder notesContent: @escaping () -> NotesContent
    ) {
        self._sheetState = sheetState
        self._selectedTab = selectedTab
        self._dragOffset = dragOffset
        self.maxUp = maxUp
        self.maxDown = maxDown
        self.overviewContent = overviewContent
        self.issuesContent = issuesContent
        self.notesContent = notesContent
    }
    
    var body: some View {
        VStack(spacing: 0) {
            dragHandle
            if sheetState != .hidden {
                tabBar
                
                sheetContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            }
        }
        .background(isDragging ? sheetBackground.opacity(1.0) : sheetBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(sheetStroke, lineWidth: 1)
                .padding(.top, 1)
        )
        .cornerRadius(20, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: -4)
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .updating($isDragging) { _, state, _ in state = true }
                .onChanged { value in
                    let translation = value.translation.height
                    dragOffset = rubberBand(translation, min: maxUp, max: maxDown)
                }
                .onEnded { value in
                    let translation = value.translation.height
                    let velocity = value.predictedEndTranslation.height - translation
                    
                    if velocity < -100 {
                        // Fast swipe up → expand
                        if let next = sheetState.nextUp {
                            withAnimation(.interactiveSpring()) {
                                sheetState = next
                            }
                        }
                    } else if velocity > 100 {
                        // Fast swipe down → collapse
                        if let next = sheetState.nextDown {
                            withAnimation(.interactiveSpring()) {
                                sheetState = next
                            }
                        }
                    } else if translation < -snapThreshold, let next = sheetState.nextUp {
                        withAnimation(.interactiveSpring()) {
                            sheetState = next
                        }
                    } else if translation > snapThreshold, let next = sheetState.nextDown {
                        withAnimation(.interactiveSpring()) {
                            sheetState = next
                        }
                    }
                    
                    withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.85, blendDuration: 0.15)) {
                        dragOffset = 0
                    }
                    // Note: dragOffset binding is reset above so parent layout updates
                }
        )
    }
    
    /// Thin horizontal grabber (Apple Maps–style); no label.
    private var dragHandle: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.white.opacity(0.35))
            .frame(width: 44, height: 4)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    Rectangle()
                        .fill(sheetBackground)
                    LinearGradient(
                        colors: [handleShadow, Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 10)
                    .frame(maxHeight: .infinity, alignment: .top)
                }
            )
    }
    
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(AnalysisSheetTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.subheadline)
                        .fontWeight(selectedTab == tab ? .semibold : .regular)
                        .foregroundColor(selectedTab == tab ? accentColor : Color.white.opacity(0.65))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
        }
        .background(sheetSurface)
    }
    
    @ViewBuilder
    private var sheetContent: some View {
        switch selectedTab {
        case .overview:
            overviewContent()
        case .issues:
            issuesContent()
        case .notes:
            notesContent()
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
