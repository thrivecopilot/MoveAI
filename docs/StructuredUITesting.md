# Structured UI Testing (Accessibility-First)

This test workflow verifies UI correctness using deterministic structure and accessibility semantics, not full pixel snapshots.

## What this covers

- Stable, identifier-based assertions (`exists`, `label`, `value`, `isEnabled`)
- Deterministic scenario launches via `-uiScenario`
- Optional accessibility auditing with `performAccessibilityAudit()`
- Lightweight JSON structural snapshots (baseline comparison)
- Visual screenshot capture only as a fallback artifact when structural checks fail

## Identifier rules

Use `accessibilityIdentifier` on every visible/interactive element you expect tests to target.

Pattern used in this project:

- Screen root: `<ScreenName>Screen`
- Section title: `<ScreenName>.<Section>Name`
- Value: `<ScreenName>.<Field>Value`
- Action: `<ScreenName>.<Action>Button`
- Repeated rows: `<ScreenName>.<RowType>.<index>`

Examples:

- `WorkoutSummary.ScoreValue`
- `PoseOverlay.Keypoint.nose`
- `DataInput.ContinueButton`

## Add identifiers in SwiftUI

```swift
Text("Score")
    .accessibilityIdentifier("WorkoutSummary.ScoreTitle")

Button("Continue") { onComplete() }
    .accessibilityIdentifier("DataInput.ContinueButton")
```

For non-text state, expose deterministic semantics on the container:

```swift
.accessibilityIdentifier("PoseOverlayView")
.accessibilityLabel("Pose Overlay")
.accessibilityValue("frame=42,keypoints=7,style=standard,source=uploaded")
```

## Deterministic scenarios

Scenarios are defined in `/Users/davemathew/Developer/MoveAI/MoveAI/Support/ScenarioRouter.swift`.

Add a scenario by:

1. Adding a `UIScenario` case.
2. Routing that case to a deterministic view in `ScenarioViews.view(...)`.
3. Seeding any required persistent state in `ScenarioFixtures.configurePersistentState(...)`.

## Test files

- `/Users/davemathew/Developer/MoveAI/MoveAIUITests/StructuredUITests.swift`
- `/Users/davemathew/Developer/MoveAI/MoveAIUITests/StructuredUITestSupport.swift`
- `/Users/davemathew/Developer/MoveAI/MoveAIUITests/StructuralSnapshotTesting.swift`
- Baselines: `/Users/davemathew/Developer/MoveAI/MoveAIUITests/StructuralSnapshots/Baselines/`

## Run tests and collect reports

```bash
bash scripts/run_ui_structured_tests.sh
```

Artifacts are written under:

- `/Users/davemathew/Developer/MoveAI/Reports/ui-structured/<timestamp>/failures.txt`
- `/Users/davemathew/Developer/MoveAI/Reports/ui-structured/<timestamp>/json-snapshots/`
- `/Users/davemathew/Developer/MoveAI/Reports/ui-structured/<timestamp>/summary.json`

## Updating structural baselines

When intentional UI semantics change:

1. Run `bash scripts/run_ui_structured_tests.sh`.
2. Compare generated `json-snapshots` files with baseline files.
3. Update baseline JSON in `/Users/davemathew/Developer/MoveAI/MoveAIUITests/StructuralSnapshots/Baselines/`.
4. Re-run tests to confirm deterministic pass.
