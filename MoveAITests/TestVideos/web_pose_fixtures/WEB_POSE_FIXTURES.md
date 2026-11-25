# Web pose fixtures

Joint positions that Squat Bot Lift Check (the web analyzer) extracted from
real clips, shared with the web engine's regression test
(`prehab2perform: tests/form-analysis/`). `SquatCameraNormalizationTests`
runs `SquatAnalyzer` on them with camera normalization on and checks rep
count and view, so the app and the web engine stay in step.

Format: `width` and `height` are the video's displayed size. Each frame has
`t` (milliseconds) and `k`, a map of joint name to `[x, y, confidence]` in
picture coordinates with y pointing up, as Vision reports them. The poses
came from MediaPipe at about 11 frames per second, not from Vision.

The source clips are in `../front_squat/iphone/` and the Muay Thai clips
alongside.
