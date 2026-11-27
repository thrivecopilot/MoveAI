#!/usr/bin/env bash
# Runs the squat analyzer's pure-logic tests on Linux, without Xcode.
#
#   bash scripts/linux-squat-tests/run.sh
#
# Needs Docker (uses the official swift:6.0-noble image). It builds a throwaway
# SwiftPM package from the real analyzer sources listed in files.txt, with
# small stand-ins for the Apple-only types they mention (Vision joint names,
# CGAffineTransform), and runs MoveAITests/SquatCameraNormalizationTests.swift
# against it.
#
# This checks the analysis logic only. It does not build the app, and it does
# not cover anything that touches Vision, AVFoundation or SwiftUI: build and
# run the full test suite in Xcode before merging.
set -euo pipefail
H="$(cd "$(dirname "$0")" && pwd)"; REPO="$(cd "$H/../.." && pwd)"; SRC="$REPO/MoveAI/Core"
P="$(mktemp -d)"; trap 'rm -rf "$P" 2>/dev/null || true' EXIT
mkdir -p "$P/Sources/MoveAI" "$P/Tests/MoveAITests"
strip() { sed -e '/^import CoreGraphics$/d' -e '/^import Vision$/d' -e '/^import UIKit$/d' -e '/^import ImageIO$/d' "$1"; }
for f in $(cat "$H/files.txt"); do strip "$SRC/$f" > "$P/Sources/MoveAI/$(basename "$f")"; done
cat > "$P/Sources/MoveAI/VisionStub.swift" <<'SW'
// Linux-only stand-in so PoseAnalysisHelpers.jointNameToString compiles without Vision.
public enum VNHumanBodyPoseObservation {
    public enum JointName {
        case nose, leftEye, rightEye, leftEar, rightEar, neck, leftShoulder, rightShoulder, leftElbow, rightElbow
        case leftWrist, rightWrist, leftHip, rightHip, root, leftKnee, rightKnee, leftAnkle, rightAnkle
    }
}
SW
# The real displayAspectRatio(naturalSize:preferredTransform:) lifted out of the AVFoundation file.
python3 - "$SRC/Utilities/VideoProcessingHelpers.swift" > "$P/Sources/MoveAI/VideoProcessingHelpersShape.swift" <<'PY'
import sys,re
s=open(sys.argv[1]).read()
a=s.index("    public static func displayAspectRatio(naturalSize:"); b=s.index("    /// Displayed width / height of the first video track")
print("import Foundation\npublic enum VideoProcessingHelpers {\n"+s[a:b].rstrip()+"\n}")
PY
strip "$REPO/MoveAITests/SquatCameraNormalizationTests.swift" > "$P/Tests/MoveAITests/SquatCameraNormalizationTests.swift"
cat > "$P/Tests/MoveAITests/FixtureDirStub.swift" <<'SW'
import Foundation
enum MuayThaiLabeledFixtureRunner { static func testVideosDirectory() -> URL { URL(fileURLWithPath: "/TestVideos") } }
SW
cat > "$P/Sources/MoveAI/CGAffineTransformStub.swift" <<'SW'
import Foundation
// Linux-only stand-in: Foundation on Linux has CGPoint/CGSize but not CGAffineTransform.
public struct CGAffineTransform {
    public var a, b, c, d, tx, ty: CGFloat
    public init(a: CGFloat, b: CGFloat, c: CGFloat, d: CGFloat, tx: CGFloat, ty: CGFloat) { self.a = a; self.b = b; self.c = c; self.d = d; self.tx = tx; self.ty = ty }
    public static let identity = CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0)
}
SW
cat > "$P/Package.swift" <<'SW'
// swift-tools-version:5.9
import PackageDescription
let package = Package(name: "MoveAI", targets: [
    .target(name: "MoveAI", swiftSettings: [.unsafeFlags(["-suppress-warnings"])]),
    .testTarget(name: "MoveAITests", dependencies: ["MoveAI"]),
])
SW
OUT="$(docker run --rm -v "$P":/pkg -v "$REPO/MoveAITests/TestVideos":/TestVideos:ro -w /pkg swift:6.0-noble \
  bash -c 'swift test 2>&1; chmod -R a+rwX /pkg 2>/dev/null' || true)"
echo "$OUT" | grep -E "error:|Test Case.*(passed|failed|skipped)|XCTAssert|Executed" | sed "s/^.*Test Case/Test Case/" | sort -u
echo "$OUT" | grep -q "with 0 failures" && ! echo "$OUT" | grep -q "error:" || { echo "LINUX SQUAT TESTS: FAIL"; exit 1; }
echo "LINUX SQUAT TESTS: PASS"
