# Video Test Cases

This directory contains test videos and their expected results for automated testing.

## Structure

Each test case consists of:
- `test_case_N.mp4` - The test video file
- `test_case_N_expected.csv` - Expected results in CSV format

### Cache and Results Directories

The testing framework automatically creates:
- `.cache/` - Cached pose extraction results (JSON files) - **ignored by git**
- `.results/` - Test result summaries and JSON outputs - **ignored by git**

These directories are created automatically when running tests and allow for faster iteration by caching expensive pose extraction.

### Muay Thai Labeled Fixtures

- `muay_thai_labeled_fixtures.json` defines labeled Muay Thai regression fixtures.
- `scripts/muay-thai-regression.sh extract` builds/refreshes cache once for all listed fixtures.
- `scripts/muay-thai-regression.sh analyze` runs cache-only regression checks for fast detector iteration.

## Adding a New Test Case

1. **Add your video file**: Place your test video as `test_case_N.mp4` in this directory

2. **Create expected results CSV**: Create `test_case_N_expected.csv` with the following format:

```csv
rep_number,start_frame,bottom_frame,end_frame,depth_quality,full_vs_partial,knee_valgus,back_rounding
1,20,93,157,EXCELLENT,Full,None,None
2,157,235,285,EXCELLENT,Full,None,None
3,300,350,430,EXCELLENT,Full,None,None
4,480,517,540,SHALLOW,Full,None,None
```

### CSV Column Descriptions

- **rep_number**: Rep number (1-indexed)
- **start_frame**: Approximate start frame of the rep
- **bottom_frame**: Approximate bottom frame of the rep (lowest point)
- **end_frame**: Approximate end frame of the rep
- **depth_quality**: `EXCELLENT` (hip crease below knee) or `SHALLOW` (optional: `SHALLOW 60%` for depth percentage)
- **full_vs_partial**: `Full` (completed range of motion) or `Partial` (incomplete)
- **knee_valgus**: `None` or `Detected`
- **back_rounding**: `None`, `Mild`, `Moderate`, or `Severe`

### Creating CSV in Google Sheets

1. Create a new Google Sheet
2. Add the header row: `rep_number,start_frame,bottom_frame,end_frame,depth_quality,full_vs_partial,knee_valgus,back_rounding`
3. Fill in your expected values for each rep
4. Download as CSV (File → Download → Comma-separated values (.csv))
5. Rename to `test_case_N_expected.csv` and place in this directory

3. **Add test method**: Add a test method in `VideoAnalysisTests.swift`:

```swift
func testCaseN() async throws {
    let testCase = try loadTestCase(name: "test_case_N")
    try await runTestCase(testCase)
}
```

## Running Tests

### In Xcode
1. Open the project in Xcode
2. Select the `MoveAITests` scheme
3. Press `Cmd+U` to run all tests
4. Or run individual test methods

### From Command Line
```bash
swift test
```

## Autonomous Testing Workflow (CLI)

This workflow uses a **standalone macOS command-line tool** (`Tools/MoveAICLI`) - no Xcode, no simulator, no app required. Vision and AVFoundation work natively on macOS.

### Prerequisites

- macOS 13+
- Swift 5.9+ (Xcode command-line tools or Xcode)
- Video file in `MoveAITests/TestVideos/` (e.g., `test_case_1.MOV`)

### Workflow: Upload Video and Extract

1. **Upload video**: Add `test_case_N.MOV` (or `.mp4`, `.mov`) to this directory
2. **Extract poses**: Run `./scripts/run-test.sh extract test_case_N` or `./scripts/extract-all-videos.sh` to extract all new videos
3. **Cache location**: Poses are stored at `MoveAITests/TestVideos/.cache/test_case_N_poses.json`
4. **Cache format**: JSON array; each element has `keypoints` (array of `{name, position: {x,y}, confidence}`), `frameIndex`, `timestamp`
5. **Downstream**: Poses in cache are consumed by `analyze` and future solvers/formulas for form feedback

### Verification

Run `cd Tools/MoveAICLI && swift test` to verify the extraction pipeline. Tests run extract and validate the cache file is readable and has valid pose structure.

### Step 1: Extract Poses Once (Slow - 2-5 minutes)

Run this once to extract and cache poses:

```bash
# From project root directory
./scripts/run-test.sh extract test_case_1
```

This runs `swift run MoveAICLI extract` and saves poses to `.cache/test_case_1_poses.json`.

**What happens:**
- Video is processed frame-by-frame using AVFoundation
- Poses are extracted using Vision framework (macOS native)
- Results are saved to `.cache/` for future use

### Step 2: Iterate on Solver (Fast - seconds)

After making changes to solver code (e.g., `SquatMechanicsSolver.swift`, `SquatMechanicsConfig.swift` in `Tools/MoveAICLI/Sources/MoveAICore/` or the main app):

```bash
./scripts/run-test.sh analyze test_case_1
```

This loads cached poses and runs analysis in seconds. Results are saved to `.results/` directory.

**What happens:**
- Cached poses are loaded (instant)
- Analysis runs with your solver changes
- Results are printed to console and saved to files
- Key metrics are highlighted for quick sanity checking

### Step 3: Review Results

**Console Output:**
- Key solver metrics (score, reps, issues)
- Detailed summary with all metrics
- File paths where results are saved

**Saved Files:**
- `MoveAITests/TestVideos/.results/test_case_1_summary.txt` - Human-readable summary
- `MoveAITests/TestVideos/.results/test_case_1_results.json` - Machine-readable JSON

### Direct CLI Usage

You can also run the CLI directly:

```bash
# Extract (with custom output path)
swift run MoveAICLI extract MoveAITests/TestVideos/test_case_1.MOV \
  --output MoveAITests/TestVideos/.cache/test_case_1_poses.json

# Analyze (with custom directories)
swift run MoveAICLI analyze test_case_1 \
  --cache-dir MoveAITests/TestVideos/.cache \
  --results-dir MoveAITests/TestVideos/.results
```

### Key Metrics to Check

When iterating on solver changes, check:

1. **Torso angle ranges** - Should vary with depth (not constant)
2. **Rep detection** - Correct number of reps detected
3. **Deviations detected** - Form issues found (torso bias, instability, hip shoot, balance drift)
4. **Overall score** - Reasonable score based on form quality

### Example Workflow

```bash
# One-time setup: Extract poses (slow, run once)
./scripts/run-test.sh extract test_case_1

# Iterate on solver changes (fast!)
# 1. Edit SquatMechanicsSolver.swift or SquatMechanicsConfig.swift
# 2. Run analysis:
./scripts/run-test.sh analyze test_case_1
# 3. Check console output and .results/ directory
# 4. Repeat steps 1-3 as needed
```

### Benefits

- **Fully autonomous**: No Xcode, no simulator, no app - pure command line
- **Direct file access**: Cache and results persist in project paths
- **Fast iteration**: Analysis in seconds
- **Reproducible**: Same commands, same results
- **Easy to automate**: Can be run by AI agents or CI/CD

## Frame Range Tolerance

Frame ranges use approximate matching with a default tolerance of ±20 frames. This accounts for:
- Frame detection variations
- Video encoding differences
- Filtering effects

## CSV Format Notes

- **Frame numbers**: Approximate - exact frames may vary slightly (±20 frames tolerance)
- **Depth quality**: 
  - `EXCELLENT` = hip crease below knee level (isAtDepth=true)
  - `SHALLOW` = hip crease not below knee level (isAtDepth=false)
  - Optional depth percentage: `SHALLOW 60%` (for approximate depth percentage)
- **Full vs Partial**:
  - `Full` = completed full range of motion (descended AND returned to start)
  - `Partial` = incomplete range of motion (didn't descend enough OR didn't return to start)
- **Knee Valgus**: `None` or `Detected`
- **Back Rounding**: `None`, `Mild`, `Moderate`, or `Severe`

## Notes

- Videos should be in a format supported by AVFoundation (MP4, MOV, etc.)
- CSV files can be created in Google Sheets and downloaded
- All columns are required (use empty values if not applicable)
- Frame numbers are approximate - exact frames may vary slightly
