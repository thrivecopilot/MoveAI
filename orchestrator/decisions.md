# Decision Journal

Runtime decisions made during execution. For the 5 pre-locked architectural decisions, see the [plan file](../.claude/plans/eager-bouncing-hejlsberg.md).

## Pre-Locked (reference)

| ID | Decision | Rationale |
|----|----------|-----------|
| A1 | Joint mapping on `FormFeedback` | Direct, Codable-safe, no indirection |
| A2 | `SessionReviewViewModel` computes highlights | Keeps overlay dumb and testable |
| A3 | Extract `CueController` from view layer | Enables unit testing of cue logic |
| A4 | Collapsed = absolute 36pt | "Handle only" per spec |
| A5 | Keep `.safeAreaInset(edge: .bottom)` for playbar | Already correct |

## Runtime Decisions

### D-001: Worktree structure — role-based, not phase-based
- **Date**: 2025-02-16
- **Context**: Needed to decide between disposable per-phase worktrees vs long-lived role-based ones
- **Decision**: 4 role-based worktrees (lead, ios, ml, review). Phases run sequentially within each worktree.
- **Alternatives**: Per-phase worktrees (more isolation but more merge overhead), single worktree with branches (simpler but no parallelism)
- **Impact**: Phases sharing files (e.g. VideoReviewLayoutView) run in the same worktree, eliminating merge conflicts

### D-002: Phase 1 and Phase 3 sequential in moveai-ios
- **Date**: 2025-02-16
- **Context**: Both phases modify `VideoReviewLayoutView.swift`
- **Decision**: Run sequentially in moveai-ios rather than in parallel
- **Alternatives**: Parallel with manual conflict resolution
- **Impact**: Simpler merge flow, no conflict risk on the most-edited file

<!-- Add new decisions below -->
