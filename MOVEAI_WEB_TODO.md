# MoveAI — Web Movement Analyzer TODO

Port the iOS MoveAI squat analysis pipeline to a self-contained browser demo.
The output is a single page (`move-analyzer.html`) that users can visit on the Prehab 2 Perform website,
upload or record a squat video, and get instant biomechanical feedback — no app install, no server.

**Source:** `MoveAI/.claude/worktrees/brave-wilson/MoveAI/Core/`
**Output:** `prehab/prototype/move-analyzer.html` + `prehab/prototype/move-analyzer/` (JS modules)

---

## Architecture Overview

```
move-analyzer.html           ← Entry point, MediaPipe CDN import, UI shell
move-analyzer/
  config.js                  ← SquatMechanicsConfig constants (direct port)
  pose-helpers.js            ← PoseAnalysisHelpers (angles, distances, smoothing)
  anthropometry.js           ← AnthropometryEstimator (segment lengths)
  rep-detector.js            ← Rep detection from SquatAnalyzer.swift
  kinematic-analyzer.js      ← KinematicAnalyzer (torso/shin angles, velocities, depths)
  mechanics-solver.js        ← SquatMechanicsSolver (ideal angle grid search)
  deviation-analyzer.js      ← FormDeviationAnalyzer (torso bias, instability, hip shoot, balance drift)
  scorer.js                  ← computeOverallFormScore
  renderer.js                ← Canvas skeleton overlay + results UI
  orchestrator.js            ← Top-level: ties all modules together, drives the pipeline
```

**MediaPipe:** Use `@mediapipe/tasks-vision` via CDN (the current stable API, not deprecated `@mediapipe/pose`).
Keypoint names from MediaPipe's 33-point BlazePose model map directly to the Swift keypoint names.
MediaPipe landmark indices to use: 11=leftShoulder, 12=rightShoulder, 23=leftHip, 24=rightHip,
25=leftKnee, 26=rightKnee, 27=leftAnkle, 28=rightAnkle, 29=leftHeel, 30=rightHeel.

All coordinates should be normalized [0,1] (MediaPipe default) — same as the Swift app after Vision normalization.

---

## ✅ Ready to Review — W1 — Scaffold `move-analyzer.html` and module structure

**What:** Create the HTML shell and all JS module files (empty exports for now).
The page has three states managed by a simple state machine:
- **idle**: Upload zone (drag-and-drop or file picker) + optional webcam record button
- **processing**: Progress bar + "Analyzing your squat…" message  
- **results**: Score display + per-rep breakdown + issue cards + video with skeleton overlay

The page must match the visual design of the rest of the prototype (use `styles.css`, same nav/footer pattern as other pages).
Import `@mediapipe/tasks-vision` from CDN: `https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@latest/vision_bundle.js`

**Files to create:**
- `prehab/prototype/move-analyzer.html`
- `prehab/prototype/move-analyzer/config.js`
- `prehab/prototype/move-analyzer/pose-helpers.js`
- `prehab/prototype/move-analyzer/anthropometry.js`
- `prehab/prototype/move-analyzer/rep-detector.js`
- `prehab/prototype/move-analyzer/kinematic-analyzer.js`
- `prehab/prototype/move-analyzer/mechanics-solver.js`
- `prehab/prototype/move-analyzer/deviation-analyzer.js`
- `prehab/prototype/move-analyzer/scorer.js`
- `prehab/prototype/move-analyzer/renderer.js`
- `prehab/prototype/move-analyzer/orchestrator.js`

**`/goal` prompt:**
```
/goal prehab/prototype/move-analyzer.html exists and loads without JS errors, imports @mediapipe/tasks-vision from CDN, has idle/processing/results UI states, matches the nav and footer of other prototype pages, and all move-analyzer/*.js module files exist with at least an empty export — verify by running: ls prehab/prototype/move-analyzer/*.js | wc -l (should be 11) and grep -c "tasks-vision" prehab/prototype/move-analyzer.html (should be >= 1)
```

---

## ✅ Ready to Review — W2 — Port `config.js` (SquatMechanicsConfig)

**What:** Direct port of all constants from `Core/Utilities/SquatMechanicsConfig.swift`.
No logic — just named exports.

**Key constants to port:**
```js
export const MIDFOOT_OFFSET_K = 0.14;
export const TORSO_ANGLE_MIN = 10, TORSO_ANGLE_MAX = 70;
export const SHIN_ANGLE_MIN = 0, SHIN_ANGLE_MAX = 45;
export const BALANCE_WEIGHT = 1.0;
export const ROM_WEIGHT = 0.5;
export const SMOOTHNESS_WEIGHT = 0.3;
export const DEPTH_CONSTRAINT_WEIGHT = 1000.0;
export const BIOMECHANICAL_WEIGHT = 50.0;
export const TORSO_DECREASE_PENALTY_WEIGHT = 10.0;
export const SHIN_ANGLE_DEFICIT_PENALTY_WEIGHT = 50.0;
export const TORSO_UPRIGHT_PENALTY_WEIGHT = 15.0;
export const HIP_SHOOT_VELOCITY_RATIO = 1.25;
export const HIP_SHOOT_DURATION_MS = 200;
export const HIP_SHOOT_TORSO_ANGLE_INCREASE = 10.0;
export const BALANCE_DRIFT_THRESHOLD = 0.12;
export const LOW_CONFIDENCE_THRESHOLD = 0.5;
export const DEPTH_STEP_SIZE = 0.05;
export const ANGLE_STEP_SIZE = 2.0;
export const MIN_SHIN_ANGLE_AT_DEPTH = 5.0;
export const COM_HIP_WEIGHT = 0.55;
export const COM_SHOULDER_WEIGHT = 0.45;
```

**`/goal` prompt:**
```
/goal prehab/prototype/move-analyzer/config.js exports MIDFOOT_OFFSET_K, TORSO_ANGLE_MIN, HIP_SHOOT_VELOCITY_RATIO, BALANCE_DRIFT_THRESHOLD, COM_HIP_WEIGHT, and at least 15 named constants total — verify by running: node -e "import('./prehab/prototype/move-analyzer/config.js').then(m => console.log(Object.keys(m).length))"
```

---

## ✅ Ready to Review — W3 — Port `pose-helpers.js` (PoseAnalysisHelpers)

**What:** Port `Core/Utilities/PoseAnalysisHelpers.swift`. These are pure math utilities used by every
downstream module. All functions are stateless.

**Functions to implement:**
- `calculateVerticalAngle(from, to)` — angle of a line segment from vertical, in degrees.
  `from` and `to` are `{x, y}` objects. Formula: `Math.atan2(|to.x - from.x|, |to.y - from.y|) * 180 / Math.PI`
- `calculateAngle(point1, vertex, point3)` — interior angle at vertex in degrees (three-point angle).
  Uses dot product: `Math.acos(clamp(dot(v1, v2) / (|v1| * |v2|), -1, 1)) * 180 / Math.PI`
- `distance(from, to)` — Euclidean distance between two `{x, y}` points
- `averagePosition(p1, p2)` — midpoint of two `{x, y}` points
- `smoothValues(values, windowSize)` — moving average smoothing, window centered on each index,
  mirrors the Swift implementation: clamp window to array bounds, average the window
- `filterByConfidence(keypoints, minConfidence)` — filter array of `{name, x, y, confidence}` objects
- `extractBilateralKeypoints(leftName, rightName, keypointMap)` — returns `[left, right]` where each
  is `{x, y, confidence}` or `null` if below threshold (0.3) or missing
- `hasSameSideHipAndKnee(keypointMap, minConfidence)` — returns true if (leftHip AND leftKnee) OR
  (rightHip AND rightKnee) are both above minConfidence

**MediaPipe keypoint name mapping (add as exported constant `KEYPOINT_NAMES`):**
```js
export const KEYPOINT_NAMES = {
  leftShoulder: 11, rightShoulder: 12,
  leftHip: 23,      rightHip: 24,
  leftKnee: 25,     rightKnee: 26,
  leftAnkle: 27,    rightAnkle: 28,
  leftHeel: 29,     rightHeel: 30,
};
```
Add a helper `landmarksToKeypointMap(landmarks)` that converts a MediaPipe `NormalizedLandmarkList`
to `{ name: {x, y, confidence} }` using the mapping above.

**`/goal` prompt:**
```
/goal prehab/prototype/move-analyzer/pose-helpers.js exports calculateVerticalAngle, calculateAngle, distance, averagePosition, smoothValues, filterByConfidence, extractBilateralKeypoints, hasSameSideHipAndKnee, landmarksToKeypointMap, and KEYPOINT_NAMES — verify with: node -e "import('./prehab/prototype/move-analyzer/pose-helpers.js').then(m => { const fns = ['calculateVerticalAngle','calculateAngle','distance','smoothValues','filterByConfidence','extractBilateralKeypoints','hasSameSideHipAndKnee','landmarksToKeypointMap']; fns.forEach(f => { if(typeof m[f] !== 'function') throw new Error('Missing: '+f); }); console.log('all present'); })"
```

---

## ✅ Ready to Review — W4 — Port `anthropometry.js` (AnthropometryEstimator)

**What:** Port `Core/Services/AnthropometryEstimator.swift`. Takes an array of per-frame keypoint maps,
returns normalized segment lengths.

**Function to implement:**
```js
export function estimateSegmentLengths(frames)
// frames: array of keypointMaps (output of landmarksToKeypointMap per frame)
// returns: { shinLength: 1.0, femurLength: number, torsoLength: number,
//            femurShinRatio: number, torsoFemurRatio: number }
// or null if insufficient data
```

**Algorithm (direct port):**
1. For each frame, extract bilateral keypoints (hip, knee, ankle, shoulder) using `extractBilateralKeypoints`
2. Compute shin (ankle→knee), femur (knee→hip), torso (hip→shoulder) distances where available
3. Collect all measurements into arrays
4. Compute median of each array (sort, take middle)
5. Normalize by median shin length (shin = 1.0, others = their_median / shin_median)
6. Return null if any of the three arrays is empty

**`/goal` prompt:**
```
/goal prehab/prototype/move-analyzer/anthropometry.js exports estimateSegmentLengths, the function accepts an array of keypointMaps and returns an object with shinLength, femurLength, torsoLength, femurShinRatio, and torsoFemurRatio (or null on insufficient data) — verify by running a unit test: node -e "import('./prehab/prototype/move-analyzer/anthropometry.js').then(m => { const result = m.estimateSegmentLengths([]); if(result !== null) throw new Error('Should return null for empty input'); console.log('null check passed'); })"
```

---

## ✅ Ready to Review — W5 — Port `rep-detector.js`

**What:** Port the rep detection logic from `SquatAnalyzer.swift` (the `detectReps` function and its helpers).
This is the most complex single piece — read the Swift source carefully.

**Input:** Array of `{ keypointMap, frameIndex, timestamp }` (valid frames only — already filtered by `hasSameSideHipAndKnee`)
**Output:** Array of `{ repNumber, startFrame, endFrame, bottomFrame, maxDepth }` — one entry per detected rep

**Algorithm:**
1. Extract hip Y-position per frame (average of leftHip.y and rightHip.y, or whichever side is available)
   In normalized [0,1] coords, higher Y = lower on screen = deeper squat
2. Apply `smoothValues` with windowSize=7 to the hip Y array
3. Find the starting height: median of first 10% of frames
4. Find the minimum depth threshold: startHeight + 0.05 (must descend at least 5% of frame height)
5. Detect reps as descent→bottom→ascent cycles:
   - Descent: hip Y increasing (going down)
   - Bottom: local maximum in hip Y that exceeds minDepthThreshold
   - Ascent: hip Y decreasing back toward start
6. A rep is valid if: duration >= 1.0s, depth >= minDepthThreshold, has clear descent and ascent
7. Return each rep with its frame range and the frame index of the deepest point

**`/goal` prompt:**
```
/goal prehab/prototype/move-analyzer/rep-detector.js exports detectReps, the function accepts an array of frame objects with keypointMap/frameIndex/timestamp and returns an array of rep objects each with repNumber, startFrame, endFrame, and bottomFrame properties — verify with: node -e "import('./prehab/prototype/move-analyzer/rep-detector.js').then(m => { if(typeof m.detectReps !== 'function') throw new Error('Missing detectReps'); const result = m.detectReps([]); if(!Array.isArray(result)) throw new Error('Should return array'); console.log('detectReps present and returns array'); })"
```

---

## ✅ Ready to Review — W6 — Port `kinematic-analyzer.js` (KinematicAnalyzer)

**What:** Port `Core/Services/KinematicAnalyzer.swift`. For each rep, compute per-frame kinematics.

**Function to implement:**
```js
export function calculateObservedKinematics(frames, rep, smoothedHipYs, repStartHeight, repBottomHeight)
// frames: full array of valid frame objects
// rep: { startFrame, endFrame, bottomFrame }
// returns: ObservedKinematics object or null
```

**Output shape:**
```js
{
  torsoAngles: number[],      // Per frame, smoothed
  shinAngles: number[],       // Per frame, smoothed
  hipAngles: number[],
  kneeAngles: number[],
  comProxy: [{x, y}],         // COM_HIP_WEIGHT * hip + COM_SHOULDER_WEIGHT * shoulder
  depths: number[],           // Normalized [0,1]: (hipY - startHeight) / (bottomHeight - startHeight)
  hipVelocities: [{x, y}],    // Central difference, px/ms
  shoulderVelocities: [{x, y}],
  frameIndices: number[],
  repNumber: number
}
```

**Key implementation notes:**
- Torso angle: `calculateVerticalAngle(shoulder, hip)` (shoulder→hip line vs vertical)
- Shin angle: `calculateVerticalAngle(ankle, knee)` (ankle→knee line vs vertical)
- Depth normalization: `clamp((hipY - repStartHeight) / (repBottomHeight - repStartHeight), 0, 1)`
- Smooth torsoAngles and shinAngles with `smoothValues(arr, 5)` before returning
- Velocities: central difference `(pos[i+1] - pos[i-1]) / (t[i+1] - t[i-1])`, forward/backward diff at endpoints
- Skip frames where both sides of hip OR shoulder are missing

**`/goal` prompt:**
```
/goal prehab/prototype/move-analyzer/kinematic-analyzer.js exports calculateObservedKinematics and the function returns an object with torsoAngles, shinAngles, depths, hipVelocities, shoulderVelocities, comProxy, and frameIndices properties (or null on insufficient data) — verify with: node -e "import('./prehab/prototype/move-analyzer/kinematic-analyzer.js').then(m => { if(typeof m.calculateObservedKinematics !== 'function') throw new Error('Missing'); console.log('present'); })"
```

---

## ✅ Ready to Review — W7 — Port `mechanics-solver.js` (SquatMechanicsSolver)

**What:** Port `Core/Services/SquatMechanicsSolver.swift`. Grid search for ideal torso/shin angles per depth.
This predicts what "perfect form" looks like for THIS person's body proportions.

**Function to implement:**
```js
export function solveIdealAngles(segmentLengths, depthSteps = null)
// segmentLengths: { shinLength, femurLength, torsoLength, femurShinRatio, torsoFemurRatio }
// depthSteps: optional array of depths [0..1], defaults to arange(0, 1.05, 0.05)
// returns: { torsoAngles: number[], shinAngles: number[], depths: number[] }
```

**Algorithm (grid search):**
For each depth step d:
1. Search all combinations of torsoAngle (10..70 step 2°) × shinAngle (0..45 step 2°)
2. For each combo, call `buildStickFigure(torsoAngle, shinAngle, segmentLengths, depth)`
3. Score each stick figure with `costFunction(stickFigure, targetDepth, segmentLengths, prevTorso, prevShin)`
4. Pick the combo with minimum cost
5. Store result; pass as `prevTorso`/`prevShin` to next depth step (smoothness penalty)

**`buildStickFigure(torsoAngle, shinAngle, segmentLengths, depth)`:**
Constructs a 2D stick figure in normalized space. Place ankle at origin (0, 0).
- knee = ankle + shin vector: `{x: sin(shinAngle°) * shin, y: -cos(shinAngle°) * shin}`
- hip = knee + femur vector (femur angle is constrained by balance): solve for hip position
- shoulder = hip + torso vector: `{x: sin(torsoAngle°) * torso, y: -cos(torsoAngle°) * torso}` (torso leans forward)
- comProxy = `COM_HIP_WEIGHT * hip + COM_SHOULDER_WEIGHT * shoulder`
- midfootEst = `{x: ankle.x + MIDFOOT_OFFSET_K * shinLength, y: ankle.y}`
- hipDepth = normalized hip height at this configuration

**`costFunction`:**
- Balance term: `(comProxy.x - midfootEst.x)^2 * BALANCE_WEIGHT`
- Depth term: `(actualDepth - targetDepth)^2 * DEPTH_CONSTRAINT_WEIGHT` (strong penalty)
- Smoothness term: if prevTorso exists, `(torsoAngle - prevTorso)^2 * SMOOTHNESS_WEIGHT + (shinAngle - prevShin)^2 * SMOOTHNESS_WEIGHT`
- Biomechanical validity: penalize torso below anthropometry minimum, shin below MIN_SHIN_ANGLE_AT_DEPTH at depth > 0

**`/goal` prompt:**
```
/goal prehab/prototype/move-analyzer/mechanics-solver.js exports solveIdealAngles and buildStickFigure, solveIdealAngles returns an object with torsoAngles, shinAngles, and depths arrays all of the same length, and the depths array contains values between 0 and 1 — verify with: node -e "import('./prehab/prototype/move-analyzer/mechanics-solver.js').then(m => { const result = m.solveIdealAngles({shinLength:1,femurLength:1.2,torsoLength:1.5,femurShinRatio:1.2,torsoFemurRatio:1.25}); if(!result.torsoAngles || result.torsoAngles.length === 0) throw new Error('No torso angles'); if(result.torsoAngles.length !== result.depths.length) throw new Error('Length mismatch'); console.log('solver ok, steps:', result.depths.length); })"
```

---

## ✅ Ready to Review — W8 — Port `deviation-analyzer.js` (FormDeviationAnalyzer)

**What:** Port `Core/Services/FormDeviationAnalyzer.swift`. Four deviation detectors + scoring.

**Functions to implement:**
```js
export function analyzeDeviations(observedKinematics, idealCurves, segmentLengths, rep)
// returns: array of FormDeviation objects

export function computeOverallFormScore(deviations)
// returns: number 0–100
```

**`FormDeviation` shape:**
```js
{ type: 'torsoBias'|'torsoInstability'|'hipShoot'|'balanceDrift',
  severity: 'mild'|'moderate'|'severe',
  magnitude: number,
  frameRange: { start: number, end: number },
  repNumber: number,
  message: string }
```

**Four detectors — port directly from Swift:**

1. **Torso Bias** (`analyzeTorsoBias`):
   - Find frames where depth >= 0.8 (bottom 20%)
   - For each, interpolate ideal torso angle from `idealCurves.torsoAngles` at that depth
   - Compute mean of (observed - predicted)
   - Flag if mean > 10°: mild >10°, moderate >15°, severe >20°

2. **Torso Instability** (`analyzeTorsoInstability`):
   - Find frames in last 20% of descent (depth 0.8→1.0) and first 30% of ascent (depth 1.0→0.7)
   - Find max delta between consecutive torso angles in those frames
   - Flag if max delta > 15°: mild >15°, moderate >20°, severe >30°

3. **Hip Shoot** (`detectHipShoot`):
   - Find frames in first 30% of ascent after bottom (depth going from 1.0 to 0.7)
   - Compute hip velocity magnitude / shoulder velocity magnitude ratio per frame
   - Flag if ratio > `HIP_SHOOT_VELOCITY_RATIO` (1.25) for >= 6 consecutive frames (≈200ms at 30fps)
   - Also flag if torso angle increases > `HIP_SHOOT_TORSO_ANGLE_INCREASE` (10°) in early ascent
   - Severity: mild, moderate >1.35, severe >1.5

4. **Balance Drift** (`analyzeBalanceDrift`):
   - Compare comProxy.x at key frames (start, bottom, mid-ascent)
   - Compute drift as deviation from initial comProxy.x, normalized by shinLength
   - Flag if drift > `BALANCE_DRIFT_THRESHOLD` (0.12 shin lengths)

**Scoring (port directly):**
- Each mild deviation: -10 points
- Each moderate: -25 points
- Each severe: -40 points
- Cap total penalty at 100, floor score at 0

**`/goal` prompt:**
```
/goal prehab/prototype/move-analyzer/deviation-analyzer.js exports analyzeDeviations and computeOverallFormScore, computeOverallFormScore([]) returns 100, computeOverallFormScore([{severity:'severe'}]) returns 60, computeOverallFormScore([{severity:'severe'},{severity:'severe'},{severity:'severe'}]) returns 0 — verify with: node -e "import('./prehab/prototype/move-analyzer/deviation-analyzer.js').then(m => { const s1=m.computeOverallFormScore([]); const s2=m.computeOverallFormScore([{severity:'severe'}]); const s3=m.computeOverallFormScore([{severity:'severe'},{severity:'severe'},{severity:'severe'}]); if(s1!==100||s2!==60||s3!==0) throw new Error('Scoring wrong: '+s1+' '+s2+' '+s3); console.log('scoring correct'); })"
```

---

## ✅ Ready to Review — W9 — Port `orchestrator.js` (pipeline assembly)

**What:** Wires all modules together. Exported as a single `analyzeVideo(file)` async function
that drives the full pipeline and returns structured results.

**Pipeline:**
```
1. Load video file as HTMLVideoElement
2. Initialize MediaPipe PoseLandmarker (WASM, from CDN)
   Model: pose_landmarker_lite (fastest, good for web)
   URL: https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_lite/float16/latest/pose_landmarker_lite.task
3. Extract frames: seek video to each frame (1/fps interval), run PoseLandmarker
   Collect: { keypointMap, frameIndex, timestamp } per frame
4. Filter frames by hasSameSideHipAndKnee(keypointMap, 0.3)
5. estimateSegmentLengths(validFrames.map(f => f.keypointMap))
6. detectReps(validFrames) → reps[]
7. For each rep:
   a. calculateObservedKinematics(validFrames, rep, smoothedHipYs, startHeight, bottomHeight)
   b. solveIdealAngles(segmentLengths)
   c. analyzeDeviations(kinematics, idealCurves, segmentLengths, rep)
   d. computeOverallFormScore(deviations)
8. Return: { reps: RepResult[], overallScore, segmentLengths, frameData }
```

**`RepResult` shape:**
```js
{ repNumber, startFrame, endFrame, score, deviations, kinematics, idealCurves }
```

**Progress callback:** `analyzeVideo(file, onProgress)` where `onProgress(pct, message)` is called
with 0–100 progress and a status string. Call at: pose init (5%), every 10% of frame extraction,
each rep analyzed (proportional to total reps), complete (100%).

**`/goal` prompt:**
```
/goal prehab/prototype/move-analyzer/orchestrator.js exports analyzeVideo as an async function that accepts a File and optional progress callback, and returns a promise that resolves to an object with reps array and overallScore — verify with: node -e "import('./prehab/prototype/move-analyzer/orchestrator.js').then(m => { if(typeof m.analyzeVideo !== 'function') throw new Error('Missing analyzeVideo'); console.log('analyzeVideo exported'); })"
```

---

## ✅ Ready to Review — W10 — Build `renderer.js` (results UI + skeleton overlay)

**What:** Takes analysis results and renders them into the page. Two responsibilities:
1. Skeleton overlay on video canvas (draw pose + angle annotations)
2. Results cards (score, per-rep breakdown, issue list)

**Canvas overlay (`renderSkeletonOverlay(canvas, keypointMap, deviations)`):**
- Draw skeleton connections in white (standard BlazePose connections: hip→knee→ankle, hip→shoulder, etc.)
- Keypoints as circles, colored by confidence (green ≥ 0.7, yellow 0.5–0.7, red < 0.5)
- If a deviation is active on this frame, highlight the relevant segment in red/orange/yellow by severity
- Draw torso angle as an arc annotation at the hip keypoint

**Results section (`renderResults(container, analysisResult)`):**
- Overall score: large number (0–100) with color (green ≥ 80, yellow 60–79, red < 60) and label ("Excellent" / "Good" / "Needs Work")
- Rep summary: one card per rep showing that rep's score and issue count
- Issues list: one card per unique deviation type found, with severity badge, description, and corrective cue

**Corrective cues (hardcoded for each deviation type):**
```js
torsoBias:       "Think 'chest up' — brace your upper back and drive your elbows down"
torsoInstability:"Control the descent — don't collapse at the bottom, stay braced"
hipShoot:        "Push your knees out and drive through your whole foot, not just your heels"
balanceDrift:    "Keep your weight over mid-foot — video from the side to check"
```

**`/goal` prompt:**
```
/goal prehab/prototype/move-analyzer/renderer.js exports renderSkeletonOverlay and renderResults, renderResults does not throw when called with a valid mock result object containing reps:[] and overallScore:85 — verify with: node -e "import('./prehab/prototype/move-analyzer/renderer.js').then(m => { if(typeof m.renderSkeletonOverlay !== 'function' || typeof m.renderResults !== 'function') throw new Error('Missing exports'); console.log('renderer exports ok'); })"
```

---

## ✅ Ready to Review — W11 — Wire `move-analyzer.html` to orchestrator + renderer

**What:** Connect the upload zone, progress bar, and results section to the real pipeline.
The HTML page was scaffolded in W1 — now wire the actual logic.

**Interactions to implement:**
1. File drop / file picker → call `analyzeVideo(file, onProgress)` → show processing state
2. `onProgress(pct, message)` → update progress bar width and label text
3. On resolve → call `renderResults(resultsContainer, result)` → show results state
4. Results section has a video player that replays the original video
5. Each rep card is clickable — clicking seeks the video to that rep's start frame and shows the skeleton overlay via `renderSkeletonOverlay` on a `<canvas>` overlaid on the video
6. On error → show error message with specific reason (no pose detected, too short, etc.)

**`/goal` prompt:**
```
/goal prehab/prototype/move-analyzer.html imports orchestrator.js and renderer.js as ES modules, has an event listener on the file input that calls analyzeVideo, updates a progress bar element during processing, and calls renderResults on completion — verify by grepping: grep -c "analyzeVideo\|renderResults\|onProgress" prehab/prototype/move-analyzer.html (should be >= 3)
```

---

## ✅ Ready to Review — W12 — Add move-analyzer.html to the nav and sitemap

**What:**
1. Add "Move Analyzer" link to the nav of `move-analyzer.html` itself (as active item)
2. Add a link/card to the existing `move-analysis.html` page pointing to the new analyzer:
   e.g. a card: "Try the Instant Analyzer — upload a video and get your form score in seconds →"
   pointing to `move-analyzer.html`
3. Add `move-analyzer.html` to `sitemap.xml` with priority 0.8
4. Update `verify.sh` to add `move-analyzer.html` to ALL_PAGES so it's covered by nav and footer checks

**`/goal` prompt:**
```
/goal prehab/prototype/sitemap.xml contains a <loc> entry for move-analyzer.html, prehab/prototype/move-analysis.html contains a link to move-analyzer.html, and bash prehab/prototype/verify.sh passes — verify by running: grep -c "move-analyzer" prehab/prototype/sitemap.xml && bash prehab/prototype/verify.sh
```

---

## 🚧 Required Before Analysis Review — P0 App-Parity Pass

The browser analyzer should match the tested iOS squat analysis behavior as closely as possible.
The current W1–W12 implementation is ready for UI/integration review, but the analysis logic should
not be treated as app-parity-complete until the items below are done.

### ✅ Implementation Ready — P0.1 — Coordinate Convention Audit
Confirm the app's effective pose coordinate convention end-to-end and make the web pipeline adapt
MediaPipe landmarks to that convention before analysis. The Swift comments currently conflict in
`SquatAnalyzer.swift` and `SquatMechanicsSolver.swift`, so the source of truth should be measured
from tested pose fixtures rather than inferred from comments.

**Acceptance criteria:**
- Same fixture pose sequence produces the same hip-height trend direction in Swift and JS.
- Rep bottoms, tops, and depth values use the same coordinate convention in both implementations.

### ✅ Implementation Ready — P0.2 — Port `SquatAnalyzer.detectReps` Fully
Replace the simplified web rep detector with the tested app logic: extrema detection, top/bottom
filtering, ascent completion validation, boundary selection, raw-height bottom refinement, partial
rep handling, and rep metadata parity.

**Acceptance criteria:**
- Same fixture pose sequence returns matching rep count, start frame, end frame, bottom frame, and
full/partial rep flags between Swift and JS.

### 🚧 Partially Implemented — P0.3 — Port Full Squat Scoring and Feedback
Bring over the app's complete squat result pipeline, not only the biomechanical deviation path:
phase detection, depth metrics, knee metrics, worst-depth/worst-knee selection, app score blending,
rep assignment, and feedback generation.

**Acceptance criteria:**
- Same fixture pose sequence produces matching overall score category and matching primary feedback
items between Swift and JS.

**Current status:** phase detection, depth metrics, knee metrics, app-style score blending, rep
assignment, and primary feedback are implemented. The app's full exhaustive feedback aggregation
still needs golden fixture validation before this should be marked complete.

### ✅ Implementation Ready — P0.4 — Port Camera-Angle and Side-View Gating
Mirror app behavior for camera-angle detection and side-view eligibility. Biomechanical deviations
should only run under the same conditions as the app.

**Acceptance criteria:**
- Front/side/unknown fixture sequences take the same analysis branches in Swift and JS.

### 🚧 Partially Implemented — P0.5 — Port `SquatMechanicsSolver` and `FormDeviationAnalyzer` Exactly
Close remaining differences in the mechanics solver and deviation analyzer, including confidence/view
angle bands, anthropometry-based constraints, fallback behavior, severity thresholds, and messages.

**Acceptance criteria:**
- Golden fixture outputs match for ideal curves, deviation types, severities, frame ranges, and per-rep
deviation scores within documented numeric tolerance.

**Current status (measured by the P0.6 harness on `test_case_1`):**
- Gate formulas and band prediction match exactly (`meanBias > torsoBand + 6`, base 5°/3° bands).
- Severity thresholds were mis-ported and are now fixed in `deviation-analyzer.js`
  (torso bias: moderate > 12°, severe > 20°; instability: moderate > 20°, severe > 25°).
- **Open gap**: JS torso-bias magnitudes run ~2–4° off Swift on the same poses
  (rep1 JS 12.82° vs Swift 8.92°, rep2 15.70° vs 12.68°, rep3 30.74° vs 32.50°), so JS emits an
  extra `squat.forward_lean` on borderline rep 1. Root cause is in the observed-kinematics /
  ideal-curve path (`kinematic-analyzer.js` / `mechanics-solver.js` / `anthropometry.js`).
  Tracked as the only `known-differences.js` entry in the parity harness — remove it when closed.

### ✅ Done — P0.6 — Add Golden Parity Fixtures
Create a repeatable fixture test flow using the same pose data for Swift and JS. Store pose fixtures
and expected outputs so future web changes can be regression-tested against the app logic.

**Acceptance criteria:**
- A single command compares JS output to exported Swift fixture expectations. ✅
- Parity tests cover at least: clean squat, shallow squat, torso bias, torso instability, hip shoot,
and poor/missing-keypoint video. ⚠️ partially — see coverage note below.

**How to run (from the MoveAI repo):**
```
bash scripts/web-parity.sh [case-name] [--refresh]
```
Exports the Swift pose cache (`MoveAICLI extract`) and analyzer results (`MoveAICLI analyze`) as
fixtures into `prehab/prototype/move-analyzer/tests/parity/fixtures/`, then runs the JS pipeline on
the same poses under macOS JavaScriptCore (`jsc -m`, no Node required) via
`tests/parity/run-parity.sh` and compares: rep count, per-rep start/bottom/end frames (±20),
full/partial and depth flags, score bucket, and issue kinds + severities + rep numbers.
Documented exceptions live in `tests/parity/known-differences.js`; anything else fails the run.

Current result on `test_case_1`: 14/15 strict checks pass (rep frames match within 0–2 frames),
1 known difference (see P0.5). The headless entry point is `analyzeFrameData()` in
`orchestrator.js`; `tests/parity/debug-deviations.js` prints per-rep deviations for debugging.

**Coverage note:** `test_case_1.MOV` exercises clean reps, shallow depth (rep 4), and torso bias
(reps 2–3). Torso instability, hip shoot, and poor/missing-keypoint scenarios need additional squat
videos — add a video to `MoveAITests/TestVideos/`, then `bash scripts/web-parity.sh <name> --refresh`
covers it automatically.

---

## 📋 Not Yet Started (needs decision)

### S1 — Webcam live analysis
Instead of upload-only, support live recording via `getUserMedia`. User hits record, does their set,
hits stop, analysis runs on the recorded blob. Requires deciding on max recording length and
whether to stream pose detection in real-time during recording (for live skeleton feedback) or
only analyze after recording stops. Recommend: show live skeleton during recording (MediaPipe runs
in real-time at ~30fps on desktop), analyze form after stop.

### S2 — Deadlift and bench press analyzers
`PoseBasedAnalysisService.swift` has stubs for these (`throw .notImplemented`). The kinematic
principles are different — deadlift needs back angle and bar path, bench needs wrist/elbow/shoulder
stack. Can be added as additional modes on the same page once squat is validated.

### S3 — Results sharing / PDF export
After analysis, offer "Download Report" as a PDF with score, rep breakdown, issues, and corrective cues.
Useful for patients to share with their PT. Use the existing `pdf` skill.

---

## ✅ Completed

- **Ready for UI/integration review:** W1–W12
- Implemented in `/Users/davemathew/Developer/prehab/prototype/move-analyzer.html` and `/Users/davemathew/Developer/prehab/prototype/move-analyzer/`.
- Verification completed:
  - `ls move-analyzer/*.js | wc -l` → `11`
  - `grep -c "tasks-vision" move-analyzer.html` → `2`
  - `grep -c "analyzeVideo\|renderResults\|onProgress" move-analyzer.html` → `6`
  - `bash verify.sh` → `139 passed, 0 failed`
  - Headless Chrome visual checks passed for desktop and mobile screenshots after layout fixes.
- **Analysis parity status:** not complete. P0.1–P0.6 must be finished before the web analyzer is considered equivalent to the tested app logic.
- **Parity implementation update:** P0.1, P0.2, P0.4, and P0.5 are implementation-ready; P0.3 has the app-style scoring path and primary feedback but still needs fixture validation; P0.6 is still required before calling parity complete.
- Browser module import smoke test passed through headless Chrome (`MODULE_OK`).
- Note: Node-based module import smoke tests were not run because no JavaScript runtime (`node`, `bun`, `deno`, `qjs`, or `jsc`) is available on PATH in this environment.
