# Screenshots

## Success criteria (agent workflow)
An **agent** must be able to execute the workflow **end to end**; the user does not run anything. This includes:
1. Running the capture script from the repo root.
2. The script completing with "Extracted N screenshots to ...".
3. The agent listing `Screenshots/latest/<newest_timestamp>/` and seeing multiple `.png` files.
4. The agent **opening** at least one PNG (e.g. a VideoReview screenshot) and **interpreting** it (e.g. reading it with the Read tool and describing the image content).

Verification is achieved only when an agent succeeds at all of the above.

## For agents: run and view results
- **Run context**: Always run from the git repo root so the correct context is used. Use:
  ```sh
  cd "$(git rev-parse --show-toplevel)" && bash scripts/capture_screenshots.sh
  ```
  If your run environment does not have a full clone (no `.git`), this will fail; see **Run environment** below. Requires Xcode and an available iOS Simulator; you may need to run outside sandbox.
- **Alternative** (if you are already at repo root): `bash scripts/capture_screenshots.sh` or `bash run_screenshots.sh`.
- **Output**: PNGs are written to `Screenshots/latest/<YYYY-MM-DD_HH-mm-ss>/` under the workspace. File names follow `screenshot__<Scenario>__<appearance>__<textSize>.png` (e.g. `screenshot__VideoReview_overview_collapsed__light__default.png`). The latest run is the folder with the newest timestamp.
- **View results**: Read the PNG files in that folder (e.g. `Screenshots/latest/<timestamp>/*.png`) to validate UI. For VideoReview work, check the `VideoReview_overview_*` screenshots; for SessionHistory, the `SessionHistory_*` ones.
- If extraction fails, see **Troubleshooting** below.

### Verification steps (agent must complete end-to-end)
1. **Run** the capture script from the repo root (use this so the correct context is used):
   ```sh
   cd "$(git rev-parse --show-toplevel)" && bash scripts/capture_screenshots.sh
   ```
   Confirm the log shows "Extracted N screenshots to ...".
2. **List** `Screenshots/latest/` and identify the newest timestamp folder (e.g. `Screenshots/latest/2026-02-13_12-00-00/`).
3. **List** the PNGs in that folder (e.g. `Screenshots/latest/<timestamp>/*.png`).
4. **Open and interpret** at least one PNG: read the file (e.g. with the Read tool) and describe the image (layout, UI elements, text). Only then is the workflow verified.
5. If no PNGs appear, check the script output for "No screenshots extracted" and the logged `OUTPUT_DIR` and any `[capture][python]` xcresulttool error; refer to **Troubleshooting** below.

## How it works
- The app checks for `-uiScenario <Name>` at launch (Debug-only). When present, it bypasses normal onboarding/navigation and routes directly to a deterministic screen with fixture data.
- UI tests launch the app with scenario + appearance (`-uiAppearance`) + text size (`-uiTextSize`) arguments and disable animations (`-uiDisableAnimations`) before capturing `XCTAttachment` screenshots with stable, predictable names.
- The capture script runs the screenshot tests via `xcodebuild` (writing the `.xcresult` bundle to a repo-local path with no spaces, `.screenshot_tmp/`, to avoid extraction issues), then exports screenshot attachments into `Screenshots/latest/<timestamp>/` using `xcrun xcresulttool get --legacy` (required on current Xcode).

## Add a new scenario in 3 steps
1. Add the scenario name + fixture data in `MoveAI/Support/ScenarioRouter.swift`. Add a new case to `UIScenario`, add a fixture in `ScenarioFixtures`, and map the case to a view in `ScenarioViews`.
2. Ensure the target view has a stable accessibility identifier so tests can wait for it (example in `MoveAI/Features/Sessions/SessionHistoryView.swift`).
3. Add the scenario to `MoveAIUITests/ScreenshotTests.swift` with the correct `waitForId`.

Current scenarios:
- `SessionHistory_loaded`
- `SessionHistory_empty`
- `SessionHistory_error`
- `SessionHistory_longText`
- `VideoReview_overview_collapsed`
- `VideoReview_overview_medium`
- `VideoReview_overview_expanded`

## Run
**Agents: always run from the git repo root** so the correct context is used:
```sh
cd "$(git rev-parse --show-toplevel)" && bash scripts/capture_screenshots.sh
```
Or from the root wrapper:
```sh
cd "$(git rev-parse --show-toplevel)" && bash run_screenshots.sh
```
If you are already at repo root: `bash scripts/capture_screenshots.sh` or `bash run_screenshots.sh`.

**From the IDE**: Run the **Capture screenshots** task (e.g. Run Task > Capture screenshots). The task is defined in `.vscode/tasks.json` with `cwd: ${workspaceFolder}` so it runs in the correct context. Use this when the agent's shell does not see the full repo.

Outputs land in:
- `Screenshots/latest/<YYYY-MM-DD_HH-mm-ss>/` — PNG files only. The raw xcresult for the current run is written to `.screenshot_tmp/` in the repo (gitignored) and is not committed.

## Extract PNGs from an existing xcresult (agent)
If a run produced an xcresult bundle but no PNGs (e.g. `Screenshots/latest/<timestamp>/MoveAI_Screenshots.xcresult` exists, no `*.png` in that folder), the **agent** should run from the repo root (for correct context):
```sh
cd "$(git rev-parse --show-toplevel)" && python3 scripts/extract_screenshots_from_xcresult.py "Screenshots/latest/<timestamp>/MoveAI_Screenshots.xcresult" "Screenshots/latest/<timestamp>"
```
Replace `<timestamp>` with the folder name (e.g. `2026-02-13_15-06-54`). PNGs are written into that folder. Requires the run environment to see the full repo (see **Run environment** below).

## Run environment (required for agents)
The **user does not run commands**; an agent must be able to run the full workflow. For that to work, the **execution environment** (the shell the agent uses) must see the **full repo**: `scripts/`, `MoveAI/`, `.git`, and after a run, `Screenshots/latest/<timestamp>/`. If the agent's shell only sees a subset (e.g. only `tasks/` and no `scripts/`), commands like `bash scripts/capture_screenshots.sh` or `python3 scripts/extract_screenshots_from_xcresult.py ...` fail with "No such file or directory" and the workflow cannot complete. There is no workaround inside the repo; the run context (Cursor or host) must provide the full workspace to the shell. If the workflow fails for this reason, try re-opening the repo root as the workspace, re-cloning into a new folder and opening that, or checking Cursor/IDE settings for how the agent's terminal working directory and filesystem view are set.

## Troubleshooting
- **No PNGs extracted**: The script writes the xcresult to `.screenshot_tmp/` (repo-local, no spaces) so `xcrun xcresulttool get --legacy` can read it reliably. The script logs `xcresult bundle (temp):` and on failure `[capture][python]` lines with xcresulttool stderr. If extraction still fails in a run where the agent can see the repo, the agent can run `xcrun xcresulttool get --legacy --format json --path <path-to-xcresult>` to inspect the error. Without `--legacy`, newer Xcode returns an error. The script falls back to `xcrun simctl io booted screenshot` and saves `fallback_booted.png` (requires a booted simulator).
- If `xcodebuild` fails, the result bundle path is logged (e.g. `.screenshot_tmp/MoveAI_Screenshots_<timestamp>.xcresult`).
- Simulator device selection prefers `iPhone 16 Pro` if available, otherwise uses any booted iPhone simulator, and falls back to the first available iPhone simulator.

## Simulator Recovery (Agents)
The capture script will automatically attempt to restart CoreSimulator if `simctl` reports “Connection invalid” or “Unable to locate device set”. If it still fails, use this manual fallback:

1. Quit Simulator (if the agent cannot, the environment owner may need to).
2. Agent runs:
```sh
xcrun simctl shutdown all
killall -9 com.apple.CoreSimulator.CoreSimulatorService
```
3. Relaunch Simulator:
```sh
open -a Simulator
```
4. Verify:
```sh
xcrun simctl list devices available
```
5. Re-run:
```sh
./scripts/capture_screenshots.sh
```

If `open -a Simulator` fails, Xcode (and the Simulator app) may not be installed or is not accessible. Confirm:
```sh
xcode-select -p
```
and ensure it points at your Xcode install (for example, `/Applications/Xcode.app/Contents/Developer`).
