# Video Test Cases

This directory contains test videos and their expected results for automated testing.

## Structure

Each test case consists of:
- `test_case_N.mp4` - The test video file
- `test_case_N_expected.csv` - Expected results in CSV format

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
