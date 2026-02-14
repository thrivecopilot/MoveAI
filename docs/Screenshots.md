# Screenshots

## Quick Reference (agent workflow)

```sh
# Edit code, then capture only the relevant screens:
bash scripts/capture_screenshots.sh --only session-history   # 12 PNGs, ~1 min
bash scripts/capture_screenshots.sh --only video-review      #  9 PNGs, ~1 min
bash scripts/capture_screenshots.sh                          # 21 PNGs, ~2 min (all)

# Read results:
# 1. Parse manifest.json to map UUID filenames → human-readable names
# 2. Read PNGs to validate your change visually
```

Previous screenshots are auto-cleaned on each run. Temp `.xcresult` bundles are auto-cleaned after extraction.

### Claude Code agents: path workaround

The repo lives under an iCloud path with special characters that the Read tool can't handle directly. Create a symlink once per session:

```sh
ln -sf "$(pwd)" /tmp/moveai_worktree
```

Then read files via `/tmp/moveai_worktree/Screenshots/latest/<timestamp>/...`.

---

## Success criteria

An **agent** must execute the workflow **end to end** (the user does not run anything):
1. Run the capture script from the repo root.
2. Script completes with "Extracted N screenshots to ...".
3. Agent reads `manifest.json` to find the relevant PNGs.
4. Agent reads at least one PNG and describes the image content.

## Partitioned captures

Use `--only` to run only the test method relevant to your change:

| Flag | Test method | Scenarios | PNGs |
|------|------------|-----------|------|
| `--only session-history` | `testSessionHistoryScreenshots` | loaded, empty, error, longText | 12 |
| `--only video-review` | `testVideoReviewScreenshots` | collapsed, medium, expanded | 9 |
| *(omitted)* | All `ScreenshotTests` | All 7 scenarios | 21 |

Each scenario produces 3 variants: light default, dark default, light large text.

## Auto-cleanup

- **Previous runs**: Each capture deletes all previous timestamp folders in `Screenshots/latest/` before starting. Use `--keep-previous` to opt out.
- **Temp xcresult**: Deleted from `.screenshot_tmp/` after successful extraction.
- **Net storage**: Only one set of screenshots exists at a time (~3-6 MB).

## How it works

1. The app checks for `-uiScenario <Name>` at launch (Debug-only). When present, `ScenarioRouter` bypasses normal onboarding/navigation and routes to a deterministic screen with fixture data.
2. UI tests in `ScreenshotTests.swift` launch the app with scenario + appearance + text size arguments, wait for a stable accessibility identifier, and capture `XCTAttachment` screenshots.
3. `capture_screenshots.sh` runs `xcodebuild test` targeting `ScreenshotTests`, then `xcrun xcresulttool export attachments` to extract PNGs + `manifest.json`.

## Current scenarios

- `SessionHistory_loaded`, `SessionHistory_empty`, `SessionHistory_error`, `SessionHistory_longText`
- `VideoReview_overview_collapsed`, `VideoReview_overview_medium`, `VideoReview_overview_expanded`

## Add a new scenario in 3 steps

1. Add the scenario name + fixture data in `MoveAI/Support/ScenarioRouter.swift`. Add a new case to `UIScenario`, a fixture in `ScenarioFixtures`, and map the case to a view in `ScenarioViews`.
2. Ensure the target view has a stable accessibility identifier (`ScenarioRoot_<name>`) so tests can wait for it.
3. Add the scenario to `MoveAIUITests/ScreenshotTests.swift` in the relevant test method (or create a new one and add an `--only` mapping in `capture_screenshots.sh`).

## Extract PNGs from an existing xcresult

If a run produced an xcresult but no PNGs:
```sh
bash scripts/extract_latest_screenshots.sh
```
This finds the latest `Screenshots/latest/<timestamp>/` and re-runs `xcrun xcresulttool export attachments`.

## Troubleshooting

- **No PNGs extracted**: Check script output for "No screenshots extracted". The script falls back to `xcrun simctl io booted screenshot` for a single fallback PNG.
- **xcodebuild fails**: Result bundle path is logged at `.screenshot_tmp/MoveAI_Screenshots_<timestamp>.xcresult`.
- **Simulator not found**: The script prefers iPhone 16 Pro (by UUID), falls back to any booted iPhone, then any available iPhone.
- **simctl connection invalid**: The script auto-retries by restarting CoreSimulator. Manual fallback:
  ```sh
  xcrun simctl shutdown all
  killall -9 com.apple.CoreSimulator.CoreSimulatorService
  open -a Simulator
  xcrun simctl list devices available
  ```

## Run environment

The agent's shell must see the full repo (`scripts/`, `MoveAI/`, `MoveAIUITests/`). If commands fail with "No such file or directory", ensure the working directory is the repo root (or a worktree that contains all source files).
