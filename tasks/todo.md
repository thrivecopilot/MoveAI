# Current Task

## Plan
- [ ] Item 1
- [ ] Item 2

## Backlog / TODO
- [x] **Video width**: Fixed via Option B — `VideoReviewLayoutView` now gives the video surface an explicit `DeviceInfo.screenWidth` frame (the failed `.ignoresSafeArea(edges: .horizontal)` attempts were removed). Guarded by `assertVideoSurfaceFullBleed()` probe assertions in `StructuralUITests` (medium/collapsed/expanded). Verified on simulator; needs a quick on-device spot check.

## Verify Plan
_Check in before starting_

## Progress
_Mark complete as you go_

## Review

### Production-readiness pass (2026-06-10)

**Data integrity**
- Imported videos now move from `tmp/` into Documents (`VideoStorage.importToPermanentStorage`) before a session references them.
- Sessions persist `videoFileName` instead of absolute container URLs (`Session`/`SessionMetadata` custom Codable); legacy absolute URLs migrate by resolving the file name against the current container.
- Deleting a session (or Delete Account) removes its video and pose sidecar; shared videos are reference-checked.
- Pose data moved to `Documents/Sessions/Poses/<id>.json` sidecars (backup-excluded, regenerable). Sessions load without pose data at launch; `SessionManager.hydratedSession`/`currentSession(for:)` hydrate on demand with a small cache. Legacy inline files split on first load.

**App Review / App Store**
- `PrivacyInfo.xcprivacy` added (UserDefaults CA92.1, no tracking, no collected data).
- Removed unused `NSHealthClinicalHealthRecordsShareUsageDescription` and `NSUserTrackingUsageDescription`.
- App icon installed from `logo.png` (the with-wordmark version, resampled to 1024², opaque). `logo_no_text.png` is also at the repo root but is not installed.
- Deployment target lowered 18.5 → 18.0.
- Sign in with Apple: credential revocation handled (launch check + notification); Profile gained Sign Out and Delete Account & Data (confirmation → wipe sessions/videos/health defaults/keychain).

**Stability / performance**
- KVO status observer replaced with auto-invalidating block observation.
- Free-running 0.1s UI timer replaced with `AVPlayer.addPeriodicTimeObserver` (token + end-of-playback observer removed in deinit).
- MetricKit crash/hang diagnostics (`CrashReportManager`) persists payloads to Application Support/Diagnostics (last 20).
- Core-service logging on `os.Logger` (`Log.storage/video/analysis/auth`); storage failures surface via alert in Session History.
- Dead code removed: `MockAnalysisService`, `LiveAnalysisService`, `PoseOverlayViewCALayer`.

**Tests**: `SessionStorageTests` (14) + `AuthLifecycleTests` (5) cover portability, migration, sidecars, deletion, keychain lifecycle, account wipe.

**Units fix (follow-up)**: profile height/weight storage is canonically metric (cm/kg) with all display formatting centralized in `ProfileUnits` (`Core/Utilities/ProfileUnits.swift`). Fixed: ProfileView formatted cm as inches ("14'9\""), the HealthKit import wrote inches/lbs into the metric keys, and PersonalInfoStepView's edit round-trip truncated an inch off the stored height. Covered by `ProfileUnitsTests` (12 tests).

### Muay Thai pass (2026-06-11)

**Test infrastructure**: the cache-backed regression failed 4/4 on a timestamp-based staleness guard although every video's SHA256 still matched its cache `.meta.json`. `MuayThaiLabeledFixtureRunner` now trusts the content hash when the mtime looks stale. Run with `bash scripts/muay-thai-regression.sh analyze cache_device` (the committed cache dir has no leading dot).

**Usability**
- Technique picker rebuilt on CoachTheme: flat list with category captions, per-technique badge (`Full analysis` for the fixture-validated jab/cross/roundhouse, `Early checks` for the rest, via `MuayThaiTechnique.analysisDepth`), stance explainer, Continue button names the choice. "Movement" renamed "Footwork".
- `MuayThaiSelectionMemory`: first launch defaults to Auto Detect; afterwards the picker restores the last mode, technique and stance.
- Recovery from a failed or wrong auto-detect: the analysis-error state offers Choose Technique, and the Overview shows the detected technique with a Change action; both re-run analysis on the existing pose data.
- Technique-aware filming tips in the camera overlay and the upload sheet (`MuayThaiTechnique.captureTip`).
- New `MuayThai_techniqueSelection` scenario in ScenarioRouter (not yet in the screenshot or structural suites).

**Tests**: `MuayThaiSelectionTests` (memory round trip, cold-start default, corrupt values, badges, tips).

**Not done from the critique**: the 0.15s chained-sheet handoff in `MovementSelectionView`; the duplicate "Muay Thai" header over the Muay Thai card.

**Signing (found 2026-11-10)**: the old Apple Development certificate expired; a new one ("Apple Development: David Mathew", valid to 2027-11-10) is now installed. Signed builds still fail because the cached team provisioning profiles (Jan/Mar 2026) were issued against the old certificate: `Provisioning profile "iOS Team Provisioning Profile: com.thrivecopilot.MoveAI" doesn't include signing certificate`. Regenerating them with `xcodebuild -allowProvisioningUpdates` was refused by Apple: `Personal development teams, including "David Mathew", do not support the Sign In with Apple capability`. Xcode's cached team record agrees (team `X3GG9GZ4JL` is "Personal Team", `isFreeProvisioningTeam = 1`), while the January 2026 profile carried the Sign in with Apple entitlement, which only a paid team can get. So the Apple Developer Program membership has most likely lapsed (not verifiable from this Mac; check developer.apple.com → Membership). Signed builds of the app are blocked until it is renewed. Until then, run the regression on the simulator: `MOVEAI_TEST_DESTINATION='platform=iOS Simulator,id=<udid>' bash scripts/muay-thai-regression.sh analyze cache_device`.

**Still open before launch**: renew the Apple Developer Program membership, then regenerate the provisioning profiles for the new signing certificate; decide between the with-wordmark icon (installed) and `logo_no_text.png`; on-device spot-checks (video width, account flows, Muay Thai recovery flow); localization decision; remote crash reporting backend (MetricKit payloads are local-only); full print() cleanup outside core services; web-analyzer P0.5 kinematics gap (tracked in MOVEAI_WEB_TODO.md + parity harness known-differences). Nothing from either pass is committed yet.
