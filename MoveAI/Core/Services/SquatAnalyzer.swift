//
//  SquatAnalyzer.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import Foundation
import CoreGraphics

/// Analyzes squat movements from pose detection data
struct SquatAnalyzer {
    
    // MARK: - Main Analysis Method
    
    /// Analyze a full sequence of poses to generate comprehensive squat analysis
    static func analyzeFullSequence(_ poseHistory: [PoseDetectionResult]) -> Result<SquatAnalysisResult, SquatAnalysisError> {
        // Check for empty pose history
        guard !poseHistory.isEmpty else {
            return .failure(.noPoseData)
        }
        
        // Check pose data quality
        // For depth analysis, we need at least one complete leg visible:
        // (leftHip AND leftKnee) OR (rightHip AND rightKnee)
        // This is more lenient than requiring all four keypoints, which helps with side-view videos
        // where one leg may be occluded
        
        // First, check if we have at least some keypoints available in the entire history
        let allKeypoints = ["leftHip", "rightHip", "leftKnee", "rightKnee"]
        let missingKeypoints = findMissingKeypoints(in: poseHistory, required: allKeypoints)
        if !missingKeypoints.isEmpty {
            // Check if we have at least one side available
            let hasLeftSide = !findMissingKeypoints(in: poseHistory, required: ["leftHip", "leftKnee"]).contains("leftHip") && 
                             !findMissingKeypoints(in: poseHistory, required: ["leftHip", "leftKnee"]).contains("leftKnee")
            let hasRightSide = !findMissingKeypoints(in: poseHistory, required: ["rightHip", "rightKnee"]).contains("rightHip") && 
                              !findMissingKeypoints(in: poseHistory, required: ["rightHip", "rightKnee"]).contains("rightKnee")
            
            if !hasLeftSide && !hasRightSide {
            return .failure(.missingRequiredKeypoints(missing: missingKeypoints))
            }
        }
        
        // Detect camera angle from pose data
        let camera = detectCameraAngle(from: poseHistory)
        let cameraAngle = camera.angle
        
        // Filter out frames with insufficient keypoints
        // Accept frames with (leftHip AND leftKnee) OR (rightHip AND rightKnee)
        var filteredFrames: [(originalIndex: Int, reason: String)] = []
        let validPoses = poseHistory.enumerated().compactMap { (index, pose) -> PoseDetectionResult? in
            if PoseAnalysisHelpers.hasSameSideHipAndKnee(pose, minConfidence: 0.3) {
                return pose
            } else {
                // Determine why frame was filtered
                let keypoints = PoseAnalysisHelpers.filterByConfidence(pose.keypoints, minConfidence: 0.3)
                let keypointNames = Set(keypoints.map { $0.name })
                let hasLeftHip = keypointNames.contains("leftHip")
                let hasLeftKnee = keypointNames.contains("leftKnee")
                let hasRightHip = keypointNames.contains("rightHip")
                let hasRightKnee = keypointNames.contains("rightKnee")
                
                var missing: [String] = []
                if !hasLeftHip { missing.append("leftHip") }
                if !hasLeftKnee { missing.append("leftKnee") }
                if !hasRightHip { missing.append("rightHip") }
                if !hasRightKnee { missing.append("rightKnee") }
                
                let reason = "Missing: \(missing.joined(separator: ", "))"
                filteredFrames.append((originalIndex: pose.frameIndex, reason: reason))
                return nil
            }
        }
        
        // Debug: Log filtering results
        print("🔍 SquatAnalyzer: Total pose history: \(poseHistory.count) frames, Valid poses after filtering: \(validPoses.count) frames")
        if !filteredFrames.isEmpty {
            print("🔍 SquatAnalyzer: Filtered out \(filteredFrames.count) frames:")
            
            // Group consecutive filtered frames to show gaps
            var gaps: [(start: Int, end: Int, count: Int)] = []
            var currentGapStart: Int? = nil
            var currentGapEnd: Int? = nil
            
            for filtered in filteredFrames.sorted(by: { $0.originalIndex < $1.originalIndex }) {
                if let start = currentGapStart {
                    if filtered.originalIndex == currentGapEnd! + 1 {
                        // Consecutive frame, extend gap
                        currentGapEnd = filtered.originalIndex
                    } else {
                        // Gap ended, save it
                        gaps.append((start: start, end: currentGapEnd!, count: currentGapEnd! - start + 1))
                        currentGapStart = filtered.originalIndex
                        currentGapEnd = filtered.originalIndex
                    }
                } else {
                    currentGapStart = filtered.originalIndex
                    currentGapEnd = filtered.originalIndex
                }
            }
            
            // Save last gap if exists
            if let start = currentGapStart {
                gaps.append((start: start, end: currentGapEnd!, count: currentGapEnd! - start + 1))
            }
            
            // Show gaps
            for gap in gaps {
                if gap.count > 5 {
                    print("  ⚠️  Large gap: Frames \(gap.start)-\(gap.end) (\(gap.count) frames) - may indicate filtering issue")
                } else {
                    print("  - Frames \(gap.start)-\(gap.end) (\(gap.count) frames)")
                }
            }
            
            // Show sample of filtered frames with reasons
            let sampleSize = min(10, filteredFrames.count)
            print("  Sample of filtered frames (showing first \(sampleSize)):")
            for filtered in filteredFrames.prefix(sampleSize) {
                print("    Frame \(filtered.originalIndex): \(filtered.reason)")
            }
            if filteredFrames.count > sampleSize {
                print("    ... and \(filteredFrames.count - sampleSize) more")
            }
        }
        
        // Check for sufficient valid frames
        // Reduced from 10 to 5 to be more lenient with imperfect videos
        // Phase detection only needs 3 frames minimum, so 5 allows for some missing detections
        let minRequiredFrames = 5
        guard validPoses.count >= minRequiredFrames else {
            return .failure(.insufficientValidFrames(count: validPoses.count, required: minRequiredFrames))
        }
        
        // Check average confidence
        let averageConfidence = calculateAverageConfidence(validPoses)
        let minConfidence: Float = 0.3
        if averageConfidence < minConfidence {
            return .failure(.lowPoseConfidence(averageConfidence: Double(averageConfidence), threshold: Double(minConfidence)))
        }
        
        // Extract hip heights and smooth for rep detection
        // Handle single-leg visibility: prefer same-side hip when available, fall back to average
        let hipHeights = validPoses.compactMap { pose -> Double? in
            let (leftHip, rightHip) = PoseAnalysisHelpers.extractBilateralKeypoints(
                leftName: "leftHip",
                rightName: "rightHip",
                from: pose
            )
            
            // Prefer same-side hip if available (for side-view videos)
            // averagePosition already handles single-leg visibility, but we're explicit here
            guard let hipPos = PoseAnalysisHelpers.averagePosition(leftHip, rightHip) else {
                return nil
            }
            return Double(hipPos.y)
        }
        
        guard hipHeights.count == validPoses.count else {
            return .failure(.invalidPoseSequence(reason: "Unable to extract hip heights"))
        }
        
        // Smooth the data to reduce noise
        let smoothedHeights = PoseAnalysisHelpers.smoothValues(hipHeights, windowSize: 5)
        
        // Get reference heights for depth calculation
        let startingHipHeight = getStartingHipHeight(validPoses)
        let minimumHipHeight = getMinimumHipHeight(validPoses)
        
        // Detect reps (descent/ascent cycles)
        let minDepthThreshold = 0.10  // Minimum 10% change in normalized height to count as a rep
        let reps = detectReps(validPoses, smoothedHeights: smoothedHeights, rawHeights: hipHeights, startHeight: startingHipHeight, minDepthThreshold: minDepthThreshold)
        
        // Detect phases (for backward compatibility, but now we have reps)
        let phases = detectPhases(validPoses)
        
        // Check if phases were detected
        guard !phases.isEmpty else {
            return .failure(.noMovementPhasesDetected)
        }
        
        // MARK: - Biomechanical Analysis (New)
        // Estimate anthropometry from pose data
        var segmentLengths: AnthropometryEstimator.SegmentLengths? = nil
        var formDeviations: [FormDeviationAnalyzer.FormDeviation] = []

        let sideViewEligible = camera.angle == .side && camera.confidence >= 0.6

        if sideViewEligible {
        
        print("🔬 ===== BIOMECHANICAL ANALYSIS START =====")
        print("🔬 Analyzing \(reps.count) reps with \(validPoses.count) valid poses")
        
        if let estimatedSegments = AnthropometryEstimator.estimateSegmentLengths(from: validPoses) {
            segmentLengths = estimatedSegments
            print("✅ Anthropometry estimated successfully:")
            print("  📏 Segment lengths (normalized by shin):")
            print("     - Shin: \(String(format: "%.3f", estimatedSegments.shinLength)) (reference = 1.0)")
            print("     - Femur: \(String(format: "%.3f", estimatedSegments.femurLength))")
            print("     - Torso: \(String(format: "%.3f", estimatedSegments.torsoLength))")
            print("  📊 Ratios:")
            print("     - Femur/Shin: \(String(format: "%.3f", estimatedSegments.femurShinRatio))")
            print("     - Torso/Femur: \(String(format: "%.3f", estimatedSegments.torsofemurRatio))")
            
            // For each rep, solve ideal angles, compute observed kinematics, and analyze deviations
            for rep in reps {
                print("\n🔬 --- Analyzing Rep \(rep.repNumber) ---")
                let repStartHeight = smoothedHeights[rep.startFrame]
                let repBottomHeight = smoothedHeights[rep.bottomFrame]
                print("  📐 Rep boundaries: start=frame \(rep.startFrame) (height \(String(format: "%.3f", repStartHeight))), bottom=frame \(rep.bottomFrame) (height \(String(format: "%.3f", repBottomHeight)))")
                
                // Solve ideal angles for this rep
                print("  🎯 Solving ideal angles...")
                let idealCurves = SquatMechanicsSolver.solveIdealAngles(
                    segmentLengths: estimatedSegments,
                    repStartHeight: repStartHeight,
                    repBottomHeight: repBottomHeight
                )
                print("  ✅ Ideal angles solved: \(idealCurves.depths.count) depth steps")
                if let firstDepth = idealCurves.depths.first, let lastDepth = idealCurves.depths.last,
                   let firstTorso = idealCurves.torsoAngles.first, let lastTorso = idealCurves.torsoAngles.last {
                    print("     - Depth range: \(String(format: "%.2f", firstDepth)) to \(String(format: "%.2f", lastDepth))")
                    print("     - Torso angle range: \(String(format: "%.1f", firstTorso))° to \(String(format: "%.1f", lastTorso))°")
                }
                
                // Compute observed kinematics
                print("  📊 Computing observed kinematics...")
                if let observedKinematics = KinematicAnalyzer.calculateObservedKinematics(
                    poses: validPoses,
                    rep: rep,
                    smoothedHeights: smoothedHeights,
                    repStartHeight: repStartHeight,
                    repBottomHeight: repBottomHeight
                ) {
                    print("  ✅ Observed kinematics computed: \(observedKinematics.torsoAngles.count) frames")
                    if let avgTorso = observedKinematics.torsoAngles.isEmpty ? nil : observedKinematics.torsoAngles.reduce(0, +) / Double(observedKinematics.torsoAngles.count),
                       let maxTorso = observedKinematics.torsoAngles.max(),
                       let minTorso = observedKinematics.torsoAngles.min() {
                        print("     - Torso angles: avg=\(String(format: "%.1f", avgTorso))°, min=\(String(format: "%.1f", minTorso))°, max=\(String(format: "%.1f", maxTorso))°")
                    }
                    
                    // Analyze deviations
                    print("  🔍 Analyzing deviations...")
                    let repDeviations = FormDeviationAnalyzer.analyzeDeviations(
                        observed: observedKinematics,
                        ideal: idealCurves,
                        segmentLengths: estimatedSegments,
                        rep: rep,
                        confidence: Double(averageConfidence),
                        isSideView: cameraAngle == .side
                    )
                    formDeviations.append(contentsOf: repDeviations)
                    
                    // Debug: Log deviations for this rep
                    if !repDeviations.isEmpty {
                        print("  ⚠️ Rep \(rep.repNumber) deviations: \(repDeviations.count) issues detected")
                        for (idx, deviation) in repDeviations.enumerated() {
                            print("     \(idx + 1). \(deviation.type) - \(deviation.severity.rawValue.uppercased())")
                            print("        Magnitude: \(String(format: "%.2f", deviation.magnitude))")
                            print("        Message: \(deviation.message)")
                            print("        Frames: \(deviation.frameRange.lowerBound)..<\(deviation.frameRange.upperBound)")
                        }
                    } else {
                        print("  ✅ No deviations detected - form looks good!")
                    }
                } else {
                    print("  ⚠️ Could not compute observed kinematics for Rep \(rep.repNumber)")
                }
            }
            
            print("\n🔬 ===== BIOMECHANICAL ANALYSIS COMPLETE =====")
            print("🔬 Total deviations found: \(formDeviations.count)")
            if !formDeviations.isEmpty {
                let byType = Dictionary(grouping: formDeviations, by: { $0.type })
                for (type, devs) in byType {
                    print("  - \(type): \(devs.count) instances")
                }
            }
        } else {
            print("⚠️ Could not estimate anthropometry - falling back to simple back angle analysis")
            print("   (This may happen if keypoints are missing or pose data is insufficient)")
        }
        
        }

        // Helper function to determine which rep a frame belongs to
        func repNumberForFrame(_ frameIndex: Int) -> Int? {
            return reps.first(where: { frameIndex >= $0.startFrame && frameIndex <= $0.endFrame })?.repNumber
        }
        
        // Calculate metrics for each phase, associating with rep numbers
        var depthMetrics: [DepthAnalysis] = []
        var kneeMetrics: [KneeAnalysis] = []
        
        for (index, pose) in validPoses.enumerated() {
            let repNum = repNumberForFrame(index)
            
            // Get rep-specific heights if this frame belongs to a rep
            var repStartHeight: Double? = nil
            var repBottomHeight: Double? = nil
            var isRepBottom = false
            if let repNum = repNum, let rep = reps.first(where: { $0.repNumber == repNum }) {
                // Use the rep's start top height and bottom height for depth percentage calculation
                repStartHeight = smoothedHeights[rep.startFrame]
                repBottomHeight = smoothedHeights[rep.bottomFrame]
                // Check if this is the bottom frame of the rep
                isRepBottom = (index == rep.bottomFrame)
            }
            
            if let depth = calculateDepth(pose, startHeight: startingHipHeight, minHeight: minimumHipHeight, repNumber: repNum, repStartHeight: repStartHeight, repBottomHeight: repBottomHeight) {
                // Debug: Log depth calculation at bottom of each rep
                if isRepBottom, let repNum = repNum {
                    print("🔍 calculateDepth at Rep \(repNum) bottom: hipY=\(String(format: "%.3f", depth.hipHeight)), kneeY=\(String(format: "%.3f", depth.kneeHeight)), isAtDepth=\(depth.isAtDepth), depthPercentage=\(String(format: "%.1f", depth.depthPercentage))%")
                    
                    if let repStart = repStartHeight, let repBottom = repBottomHeight {
                        print("  - Using rep-specific heights: start=\(String(format: "%.3f", repStart)), bottom=\(String(format: "%.3f", repBottom))")
                    } else {
                        print("  - Using global heights: start=\(String(format: "%.3f", startingHipHeight)), bottom=\(String(format: "%.3f", minimumHipHeight))")
                    }
                }
                depthMetrics.append(depth)
            }
            if let knee = calculateKneeAngles(pose, repNumber: repNum, cameraAngle: cameraAngle) {
                kneeMetrics.append(knee)
            }
            
            // Back analysis is now handled entirely by biomechanical deviations (formDeviations)
            // No simple angle-based analysis is performed
        }
        
        // Validate we have enough metrics
        // Prioritize depth metrics (core analysis) - must have at least depth analysis
        // Knee and back analyses are optional and can be missing
        guard !depthMetrics.isEmpty else {
            return .failure(.invalidPoseSequence(reason: "Unable to calculate depth metrics - hips and knees required"))
        }
        
        // Filter metrics to only include those with rep numbers
        // This ensures all feedback items will have rep numbers for proper rep counting
        let depthMetricsWithReps = depthMetrics.filter { $0.repNumber != nil }
        let kneeMetricsWithReps = kneeMetrics.filter { $0.repNumber != nil }
        
        // Find worst-case scenarios from metrics that have rep numbers
        // If no metrics with rep numbers exist, fall back to all metrics and assign rep numbers
        let worstDepthCandidate = (depthMetricsWithReps.isEmpty ? depthMetrics : depthMetricsWithReps).min { $0.depthPercentage < $1.depthPercentage }
        let worstKneeAngleCandidate = (kneeMetricsWithReps.isEmpty ? kneeMetrics : kneeMetricsWithReps).min { $0.minAngle < $1.minAngle }
        
        // Ensure all worst metrics have rep numbers (assign to nearest rep if missing)
        let worstDepth = worstDepthCandidate.flatMap { depth in
            depth.repNumber != nil ? depth : assignRepNumberToDepthMetric(depth, reps: reps)
        }
        let worstKneeAngle = worstKneeAngleCandidate.flatMap { knee in
            knee.repNumber != nil ? knee : assignRepNumberToKneeMetric(knee, reps: reps)
        }
        
        // Calculate overall score based on all reps (not just worst case)
        let score = calculateOverallScore(
            reps: reps,
            depthMetrics: depthMetricsWithReps.isEmpty ? depthMetrics : depthMetricsWithReps,
            kneeMetrics: kneeMetricsWithReps.isEmpty ? kneeMetrics : kneeMetricsWithReps,
            formDeviations: formDeviations
        )
        
        // Generate feedback (using relative timestamps from start of recording)
        // Use the first pose timestamp (not first *valid* pose) to avoid shifting time when frames are filtered.
        let startTime = poseHistory.first?.timestamp ?? Date()
        let feedback = generateFeedback(
            poses: validPoses,
            smoothedHeights: smoothedHeights,
            phases: phases,
            reps: reps,
            depthMetrics: depthMetrics,
            kneeMetrics: kneeMetrics,
            worstDepth: worstDepth,
            worstKnee: worstKneeAngle,
            startTime: startTime,
            camera: camera,
            segmentLengths: segmentLengths,
            formDeviations: formDeviations
        )
        
        let result = SquatAnalysisResult(
            phases: phases,
            reps: reps,
            depthMetrics: depthMetrics,
            kneeMetrics: kneeMetrics,
            worstDepth: worstDepth,
            worstKneeAngle: worstKneeAngle,
            overallScore: score,
            feedback: feedback
        )
        
        return .success(result)
    }
    
    // MARK: - Rep Detection
    
    /// Detect multiple squat reps by finding descent/ascent cycles
    /// Returns an array of SquatRep structs, one for each detected rep
    static func detectReps(
        _ poses: [PoseDetectionResult],
        smoothedHeights: [Double],
        rawHeights: [Double],
        startHeight: Double,
        minDepthThreshold: Double
    ) -> [SquatRep] {
        guard poses.count >= 3, 
              smoothedHeights.count == poses.count,
              rawHeights.count == poses.count else { return [] }
        
        var reps: [SquatRep] = []

        func median(_ values: [Double]) -> Double? {
            guard !values.isEmpty else { return nil }
            let sorted = values.sorted()
            let mid = sorted.count / 2
            if sorted.count % 2 == 0 {
                return (sorted[mid - 1] + sorted[mid]) / 2.0
            }
            return sorted[mid]
        }

        let setupFrameCount = min(5, smoothedHeights.count)
        let setupHeights = Array(smoothedHeights.prefix(setupFrameCount))
        let setupMedianHeight = median(setupHeights) ?? startHeight

        // Note: In normalized coordinates, Y decreases downward
        // When hip is at bottom (lowest), Y is minimum
        // When hip is at top (highest), Y is maximum
        var bottoms: [Int] = []  // Frame indices of bottom positions (local minima in Y)
        var tops: [Int] = []     // Frame indices of top positions (local maxima in Y)
        
        // Window size for detecting local extrema (avoid noise)
        let windowSize = 5
        
        // Find local minima (bottom positions - hip is lowest, Y is minimum)
        for i in windowSize..<(smoothedHeights.count - windowSize) {
            let current = smoothedHeights[i]
            let isLocalMin = (1...windowSize).allSatisfy { offset in
                smoothedHeights[i - offset] >= current && smoothedHeights[i + offset] >= current
            }
            if isLocalMin {
                bottoms.append(i)
            }
        }
        
        // Find local maxima (top positions - hip is highest, Y is maximum)
        for i in windowSize..<(smoothedHeights.count - windowSize) {
            let current = smoothedHeights[i]
            let isLocalMax = (1...windowSize).allSatisfy { offset in
                smoothedHeights[i - offset] <= current && smoothedHeights[i + offset] <= current
            }
            if isLocalMax {
                tops.append(i)
            }
        }
        
        // Calculate movement range for relative filtering
        // Find the minimum height (deepest bottom) in the sequence
        let minHeight = smoothedHeights.min() ?? startHeight
        let movementRange = startHeight - minHeight
        guard movementRange > 0 else {
            print("⚠️ detectReps: Invalid movement range (startHeight=\(String(format: "%.3f", startHeight)), minHeight=\(String(format: "%.3f", minHeight)))")
            return []
        }
        
        print("🔍 detectReps: Movement range analysis:")
        print("  - Start height: \(String(format: "%.3f", startHeight))")
        print("  - Min height: \(String(format: "%.3f", minHeight))")
        print("  - Movement range: \(String(format: "%.3f", movementRange))")
        
        // Relative height thresholds
        let topHeightThreshold = 0.10  // Tops must be within 10% of startHeight (relative)
        let bottomDepthThreshold = 0.20  // Bottoms must represent at least 20% of movement range
        let minDepthChange = 0.05  // Minimum 5% change in normalized height (for initial filtering)
        
        // Track filtered extrema for debugging
        var filteredTops: [(index: Int, reason: String)] = []
        var filteredBottoms: [(index: Int, reason: String)] = []
        
        // Filter tops: Must be within threshold of startHeight (relative height check)
        let validTops = tops.filter { index in
            guard index > 0 && index < smoothedHeights.count - 1 else {
                filteredTops.append((index, "Out of bounds"))
                return false
            }
            
            let topHeight = smoothedHeights[index]
            let heightDifference = abs(topHeight - startHeight)
            let relativeDifference = startHeight > 0 ? heightDifference / startHeight : heightDifference
            
            // Check if top is close enough to startHeight
            if relativeDifference > topHeightThreshold {
                let originalFrame = index < poses.count ? poses[index].frameIndex : -1
                filteredTops.append((index, "Too far from startHeight: \(String(format: "%.1f", relativeDifference * 100))% (height=\(String(format: "%.3f", topHeight)), startHeight=\(String(format: "%.3f", startHeight)))"))
                return false
            }
            
            // Also check if there's a significant descent/ascent around this top (original check)
            let hasSignificantChange = bottoms.contains { bottom in
                abs(smoothedHeights[bottom] - topHeight) > minDepthChange
            }
            if !hasSignificantChange {
                filteredTops.append((index, "No significant change from nearby bottoms"))
                return false
            }
            
            return true
        }
        
        // Filter bottoms: Must represent significant descent (at least 20% of movement range)
        let validBottoms = bottoms.filter { index in
            guard index > 0 && index < smoothedHeights.count - 1 else {
                filteredBottoms.append((index, "Out of bounds"))
                return false
            }
            
            let bottomHeight = smoothedHeights[index]
            let depthFromStart = startHeight - bottomHeight
            let depthPercentage = movementRange > 0 ? depthFromStart / movementRange : 0
            
            // Check if bottom represents sufficient descent
            if depthPercentage < bottomDepthThreshold {
                let originalFrame = index < poses.count ? poses[index].frameIndex : -1
                filteredBottoms.append((index, "Insufficient depth: \(String(format: "%.1f", depthPercentage * 100))% of range (height=\(String(format: "%.3f", bottomHeight)), needs at least \(String(format: "%.1f", bottomDepthThreshold * 100))%)"))
                return false
            }
            
            // Also check if there's a significant change from nearby tops (original check)
            let hasSignificantChange = tops.contains { top in
                abs(bottomHeight - smoothedHeights[top]) > minDepthChange
            }
            if !hasSignificantChange {
                filteredBottoms.append((index, "No significant change from nearby tops"))
                return false
            }
            
            return true
        }
        
        // Update tops and bottoms with filtered results
        tops = validTops
        bottoms = validBottoms
        
        // Ascent completion validation: Filter tops that haven't ascended enough from nearest bottom
        let ascentCompletionThreshold = 0.50  // Must ascend at least 50% of the way back to startHeight
        var ascentFilteredTops: [(index: Int, reason: String)] = []
        
        let topsWithAscent = tops.filter { topIndex in
            let topHeight = smoothedHeights[topIndex]
            
            // Find the nearest bottom before this top
            let nearestBottom = bottoms.filter { $0 < topIndex }.max()
            
            guard let bottomIndex = nearestBottom else {
                // No bottom before this top - might be initial setup, allow it
                return true
            }
            
            let bottomHeight = smoothedHeights[bottomIndex]
            let ascentRange = topHeight - bottomHeight
            let totalRangeToStart = startHeight - bottomHeight
            
            guard totalRangeToStart > 0 else {
                ascentFilteredTops.append((topIndex, "Bottom height >= startHeight (invalid)"))
                return false
            }
            
            let ascentProgress = ascentRange / totalRangeToStart
            
            if ascentProgress < ascentCompletionThreshold {
                let originalTopFrame = topIndex < poses.count ? poses[topIndex].frameIndex : -1
                let originalBottomFrame = bottomIndex < poses.count ? poses[bottomIndex].frameIndex : -1
                ascentFilteredTops.append((topIndex, "Insufficient ascent: \(String(format: "%.1f", ascentProgress * 100))% (top=\(String(format: "%.3f", topHeight)), bottom=\(String(format: "%.3f", bottomHeight)), needs at least \(String(format: "%.1f", ascentCompletionThreshold * 100))%)"))
                return false
            }
            
            return true
        }
        
        tops = topsWithAscent
        
        // Debug: Log ascent-filtered tops
        if !ascentFilteredTops.isEmpty {
            print("🔍 detectReps: Filtered out \(ascentFilteredTops.count) tops due to insufficient ascent:")
            for filtered in ascentFilteredTops.prefix(10) {
                let originalFrame = filtered.index < poses.count ? poses[filtered.index].frameIndex : -1
                print("  - Filtered top at filtered \(filtered.index) (original \(originalFrame)): \(filtered.reason)")
            }
            if ascentFilteredTops.count > 10 {
                print("  ... and \(ascentFilteredTops.count - 10) more")
            }
        }
        
        // Debug: Log filtered extrema
        if !filteredTops.isEmpty {
            print("🔍 detectReps: Filtered out \(filteredTops.count) tops:")
            for filtered in filteredTops.prefix(10) {
                let originalFrame = filtered.index < poses.count ? poses[filtered.index].frameIndex : -1
                print("  - Filtered top at filtered \(filtered.index) (original \(originalFrame)): \(filtered.reason)")
            }
            if filteredTops.count > 10 {
                print("  ... and \(filteredTops.count - 10) more")
            }
        }
        
        if !filteredBottoms.isEmpty {
            print("🔍 detectReps: Filtered out \(filteredBottoms.count) bottoms:")
            for filtered in filteredBottoms.prefix(10) {
                let originalFrame = filtered.index < poses.count ? poses[filtered.index].frameIndex : -1
                print("  - Filtered bottom at filtered \(filtered.index) (original \(originalFrame)): \(filtered.reason)")
            }
            if filteredBottoms.count > 10 {
                print("  ... and \(filteredBottoms.count - 10) more")
            }
        }
        
        // Debug: Log detected extrema with original frame numbers
        let topsWithFrames = tops.map { (index: $0, originalFrame: $0 < poses.count ? poses[$0].frameIndex : -1) }
        let bottomsWithFrames = bottoms.map { (index: $0, originalFrame: $0 < poses.count ? poses[$0].frameIndex : -1) }
        print("🔍 detectReps: Found \(tops.count) tops:")
        for (index, originalFrame) in topsWithFrames {
            print("  - Top at filtered index \(index) (original frame \(originalFrame)), height=\(String(format: "%.3f", smoothedHeights[index]))")
        }
        print("🔍 detectReps: Found \(bottoms.count) bottoms:")
        for (index, originalFrame) in bottomsWithFrames {
            print("  - Bottom at filtered index \(index) (original frame \(originalFrame)), height=\(String(format: "%.3f", smoothedHeights[index]))")
        }
        
        // Helper function to find where descent begins before a top
        // Looks backwards from the top to find where Y starts decreasing (descent begins)
        func findDescentStart(before topIndex: Int, in heights: [Double], startHeight: Double) -> Int {
            guard topIndex < heights.count else { return max(0, topIndex - 1) }
            let topHeight = heights[topIndex]
            let threshold = 0.02 // 2% change to detect descent start
            
            // Look backwards from top to find where Y starts decreasing (descent begins)
            // Since Y decreases downward, descent means Y goes from higher to lower
            // Limit search to 50 frames back to avoid going too far
            for i in stride(from: topIndex - 1, through: max(0, topIndex - 50), by: -1) {
                let heightDiff = topHeight - heights[i]  // Reversed: top - previous
                let relativeChange = topHeight > 0 ? heightDiff / topHeight : heightDiff
                
                // If we've moved significantly toward lower Y (descent started), return this frame
                if relativeChange > threshold {
                    return i + 1 // Return frame just before descent
                }
            }
            return max(0, topIndex - 1) // Fallback
        }
        
        // Group into cycles: start at a top → descend to bottom → ascend to next top
        // We need at least one top to start from, or start from beginning
        var repNumber = 1
        var cycleStart = 0
        
        // If we have tops, find where descent begins before the first top
        if let firstTop = tops.first, firstTop > 0 {
            cycleStart = findDescentStart(before: firstTop, in: smoothedHeights, startHeight: startHeight)
        }
        
        var currentTopIndex = 0
        
        while currentTopIndex < tops.count {
            let startTop = tops[currentTopIndex]
            
            // Set cycleStart to startTop at the beginning of each iteration
            // This ensures each rep starts from the correct top
            // For the first iteration, cycleStart was already set by findDescentStart
            if currentTopIndex > 0 {
                cycleStart = startTop
            }
            
            // Find the next top after startTop (to check if we should split the rep)
            // Validate that it's a valid rep boundary before using it
            let startTopHeight = smoothedHeights[startTop]
            let repBoundaryHeightThreshold = 0.10  // Must be within 10% of startTopHeight
            
            // Helper function to validate if a top is a valid rep boundary
            func isValidRepBoundary(_ topIndex: Int) -> Bool {
                let topHeight = smoothedHeights[topIndex]
                let heightDifference = abs(topHeight - startTopHeight)
                let relativeDifference = startTopHeight > 0 ? heightDifference / startTopHeight : heightDifference
                
                // Check if height is close enough to starting top
                if relativeDifference > repBoundaryHeightThreshold {
                    return false
                }
                
                // Check if it has ascended sufficiently from nearest bottom
                let nearestBottom = bottoms.filter { $0 < topIndex && $0 > startTop }.max()
                if let bottomIndex = nearestBottom {
                    let bottomHeight = smoothedHeights[bottomIndex]
                    let ascentRange = topHeight - bottomHeight
                    let totalRangeToStart = startTopHeight - bottomHeight
                    
                    if totalRangeToStart > 0 {
                        let ascentProgress = ascentRange / totalRangeToStart
                        if ascentProgress < 0.50 {  // Must ascend at least 50% of way back
                            return false
                        }
                    }
                }
                
                return true
            }
            
            // Find the next valid top candidate (skip invalid ones)
            var nextTopCandidate: Int? = nil
            var skippedTops: [(index: Int, reason: String)] = []
            
            for candidateIndex in tops where candidateIndex > startTop {
                if isValidRepBoundary(candidateIndex) {
                    nextTopCandidate = candidateIndex
                    break
                } else {
                    let candidateHeight = smoothedHeights[candidateIndex]
                    let heightDiff = abs(candidateHeight - startTopHeight)
                    let relativeDiff = startTopHeight > 0 ? heightDiff / startTopHeight : heightDiff
                    let originalFrame = candidateIndex < poses.count ? poses[candidateIndex].frameIndex : -1
                    
                    var reason = "Height difference: \(String(format: "%.1f", relativeDiff * 100))% (needs < \(String(format: "%.1f", repBoundaryHeightThreshold * 100))%)"
                    
                    // Check ascent if there's a bottom
                    if let nearestBottom = bottoms.filter({ $0 < candidateIndex && $0 > startTop }).max() {
                        let bottomHeight = smoothedHeights[nearestBottom]
                        let ascentRange = candidateHeight - bottomHeight
                        let totalRangeToStart = startTopHeight - bottomHeight
                        if totalRangeToStart > 0 {
                            let ascentProgress = ascentRange / totalRangeToStart
                            if ascentProgress < 0.50 {
                                reason += ", Insufficient ascent: \(String(format: "%.1f", ascentProgress * 100))% (needs >= 50%)"
                            }
                        }
                    }
                    
                    skippedTops.append((candidateIndex, reason))
                }
            }
            
            // Debug: Log skipped tops
            if !skippedTops.isEmpty {
                print("🔍 detectReps: Rep \(repNumber + 1) - Skipped \(skippedTops.count) invalid top candidate(s):")
                for skipped in skippedTops {
                    let originalFrame = skipped.index < poses.count ? poses[skipped.index].frameIndex : -1
                    print("  - Skipped top at filtered \(skipped.index) (original \(originalFrame)): \(skipped.reason)")
                }
            }
            
            // Find the next bottom after this top
            guard let nextBottom = bottoms.first(where: { $0 > startTop }) else {
                // No bottom found after this top - might be end of recording
                // Check if we have a significant descent that could be a partial rep
                if startTop < poses.count - 10 {
                    // Look for any significant movement after this top
                    let endFrame = poses.count - 1
                    let endHeight = smoothedHeights[endFrame]
                    let startTopHeight = smoothedHeights[startTop]
                    let absoluteHeightChange = abs(endHeight - startTopHeight)
                    // Calculate as relative percentage
                    let heightChange = startTopHeight > 0 ? absoluteHeightChange / startTopHeight : absoluteHeightChange
                    
                    if heightChange > minDepthThreshold {
                        // Partial rep - descended but didn't complete
                        let originalStartFrame = poses[cycleStart].frameIndex
                        let originalEndFrame = poses[endFrame].frameIndex
                        print("🔍 detectReps: Creating partial rep: filtered frames \(cycleStart)-\(endFrame) (original frames \(originalStartFrame)-\(originalEndFrame))")
                        print("  - Height change: absolute=\(String(format: "%.3f", absoluteHeightChange)), relative=\(String(format: "%.1f", heightChange * 100))%")
                        reps.append(SquatRep(
                            repNumber: repNumber,
                            startFrame: cycleStart,
                            endFrame: endFrame,
                            startTime: poses[cycleStart].timestamp.timeIntervalSince1970,
                            endTime: poses[endFrame].timestamp.timeIntervalSince1970,
                            isFullRep: false,
                            bottomFrame: endFrame,
                            bottomTime: poses[endFrame].timestamp.timeIntervalSince1970,
                            reachedDepth: false,
                            returnedToStart: false
                        ))
                    }
                }
                break
            }
            
            // Determine the rep end and actual bottom
            // Always use nextTopCandidate when it exists, regardless of position relative to bottom
            let nextTop: Int
            let actualBottom: Int
            let actualBottomHeight: Double
            
            if let candidate = nextTopCandidate {
                // Always use the next top candidate as the rep end
                nextTop = candidate
                
                // Find the bottom between startTop and this candidate top
                // Since Y decreases downward, bottom = minimum Y value
                let bottomRange = (startTop + 1)..<candidate
                if let foundBottom = bottomRange.min(by: { smoothedHeights[$0] < smoothedHeights[$1] }) {
                    // Phase 1: Found smoothed minimum
                    let smoothedBottom = foundBottom
                    let smoothedBottomHeight = smoothedHeights[smoothedBottom]
                    
                    // Phase 2: Refine with raw height check in small window around smoothed minimum
                    let refinementWindow = 10  // Check ±10 frames around smoothed minimum
                    let refinementStart = max(startTop + 1, smoothedBottom - refinementWindow)
                    let refinementEnd = min(candidate, smoothedBottom + refinementWindow + 1)
                    let refinementRange = refinementStart..<refinementEnd
                    
                    // ENHANCED DEBUGGING: Detailed Refinement Window Analysis
                    print("🔍 detectReps: Refinement Window Analysis for Rep \(repNumber + 1):")
                    print("  - Smoothed minimum: filtered \(smoothedBottom) (original frame \(poses[smoothedBottom].frameIndex)), height=\(String(format: "%.3f", smoothedBottomHeight))")
                    print("  - Refinement window: filtered indices \(refinementStart)..<\(refinementEnd) (original frames \(poses[refinementStart].frameIndex)..<\(poses[min(refinementEnd - 1, poses.count - 1)].frameIndex))")
                    print("  - Window size: \(refinementEnd - refinementStart) frames (±\(refinementWindow) frames around smoothed minimum)")
                    
                    // Analyze all candidates in refinement window
                    var candidates: [(index: Int, rawHeight: Double, smoothedHeight: Double, improvement: Double, smoothedDiff: Double)] = []
                    for idx in refinementRange {
                        guard idx < rawHeights.count && idx < smoothedHeights.count else { continue }
                        let rawH = rawHeights[idx]
                        let smoothedH = smoothedHeights[idx]
                        let improvement = smoothedBottomHeight - rawH  // How much better is raw than smoothed minimum
                        let smoothedDiff = abs(smoothedH - smoothedBottomHeight)  // How close is smoothed value to smoothed minimum
                        candidates.append((idx, rawH, smoothedH, improvement, smoothedDiff))
                    }
                    
                    // Sort by raw height (best candidates first)
                    candidates.sort { $0.rawHeight < $1.rawHeight }
                    
                    print("  - All candidates in refinement window (sorted by raw height, best first):")
                    for (idx, candidate) in candidates.enumerated() {
                        let originalFrame = poses[candidate.index].frameIndex
                        let significantImprovement = candidate.improvement > 0.01
                        let reasonableSmoothed = candidate.smoothedDiff < 0.02
                        let wouldBeSelected = significantImprovement && reasonableSmoothed
                        
                        var reasons: [String] = []
                        if !significantImprovement {
                            reasons.append("improvement too small (\(String(format: "%.3f", candidate.improvement)) <= 0.01)")
                        }
                        if !reasonableSmoothed {
                            reasons.append("smoothed diff too large (\(String(format: "%.3f", candidate.smoothedDiff)) >= 0.02)")
                        }
                        if wouldBeSelected {
                            reasons.append("✓ SELECTED")
                        }
                        
                        let reasonStr = reasons.isEmpty ? "" : " [\(reasons.joined(separator: ", "))]"
                        let rankMarker = idx == 0 ? " (BEST RAW)" : ""
                        print("    \(idx + 1). Filtered \(candidate.index) (original \(originalFrame)): raw=\(String(format: "%.3f", candidate.rawHeight)), smoothed=\(String(format: "%.3f", candidate.smoothedHeight)), improvement=\(String(format: "%.3f", candidate.improvement)), smoothedDiff=\(String(format: "%.3f", candidate.smoothedDiff))\(rankMarker)\(reasonStr)")
                    }
                    
                    // Find raw minimum in refinement window
                    if let rawBottom = refinementRange.min(by: { rawHeights[$0] < rawHeights[$1] }) {
                        let rawBottomHeight = rawHeights[rawBottom]
                        let smoothedAtRawBottom = smoothedHeights[rawBottom]
                        
                        // Use raw minimum if it's significantly better (at least 0.01 lower in normalized coordinates)
                        // and smoothed value at that frame is still reasonable (within 0.02 of smoothed minimum)
                        let rawImprovement = smoothedBottomHeight - rawBottomHeight
                        let smoothedDifference = abs(smoothedAtRawBottom - smoothedBottomHeight)
                        let significantImprovement = rawImprovement > 0.01  // Raw is at least 0.01 lower
                        let reasonableSmoothed = smoothedDifference < 0.02  // Smoothed value still close to minimum
                        
                        print("  - Refinement Decision:")
                        print("    Raw minimum: filtered \(rawBottom) (original \(poses[rawBottom].frameIndex)), raw=\(String(format: "%.3f", rawBottomHeight)), smoothed=\(String(format: "%.3f", smoothedAtRawBottom))")
                        print("    Improvement: \(String(format: "%.3f", rawImprovement)) (threshold: 0.01) - \(significantImprovement ? "✓ PASS" : "✗ FAIL")")
                        print("    Smoothed diff: \(String(format: "%.3f", smoothedDifference)) (threshold: 0.02) - \(reasonableSmoothed ? "✓ PASS" : "✗ FAIL")")
                        
                        if significantImprovement && reasonableSmoothed {
                            // Use refined bottom (raw minimum)
                            actualBottom = rawBottom
                            actualBottomHeight = smoothedHeights[rawBottom]
                            
                            print("    → Using refined bottom: filtered \(rawBottom) (improvement=\(String(format: "%.3f", rawImprovement)))")
                        } else {
                            // Keep smoothed minimum
                            actualBottom = smoothedBottom
                            actualBottomHeight = smoothedBottomHeight
                            print("    → Keeping smoothed minimum (refinement criteria not met)")
                        }
                    } else {
                        // Fallback: use smoothed minimum
                        actualBottom = smoothedBottom
                        actualBottomHeight = smoothedBottomHeight
                        print("    → No raw minimum found in refinement window, using smoothed minimum")
                    }
                    
                    // Debug: Log smoothed heights around the detected bottom for all reps
                    print("🔍 detectReps: Bottom detection for Rep \(repNumber + 1):")
                    print("  - Range: filtered indices \(startTop + 1)..<\(candidate) (original frames ~\(poses[startTop + 1].frameIndex)..<\(poses[min(candidate - 1, poses.count - 1)].frameIndex))")
                    print("  - Detected bottom: filtered index \(actualBottom) (original frame \(poses[actualBottom].frameIndex)), smoothed height=\(String(format: "%.3f", actualBottomHeight))")
                    
                    // ENHANCED DEBUGGING: Rep Range Analysis - Show raw vs smoothed heights across entire rep range
                    let repStartFrame = poses[startTop + 1].frameIndex
                    let repEndFrame = poses[min(candidate - 1, poses.count - 1)].frameIndex
                    print("🔍 detectReps: Rep \(repNumber + 1) Range Analysis (original frames \(repStartFrame)-\(repEndFrame)):")
                    
                    // Sample frames across the rep range (every 10th frame, plus key points)
                    let sampleInterval = max(1, (candidate - startTop - 1) / 20) // Sample ~20 points
                    var sampleFrames: Set<Int> = []
                    
                    // Add start, detected bottom region, and end
                    sampleFrames.insert(startTop + 1)
                    sampleFrames.insert(actualBottom)
                    if let smoothedBottom = bottomRange.min(by: { smoothedHeights[$0] < smoothedHeights[$1] }) {
                        sampleFrames.insert(smoothedBottom)
                    }
                    sampleFrames.insert(candidate - 1)
                    
                    // Add samples across the range
                    for i in stride(from: startTop + 1, to: candidate, by: sampleInterval) {
                        sampleFrames.insert(i)
                    }
                    
                    // Add frames around detected bottom (±20 frames for detailed view)
                    for offset in -20...20 {
                        let frameIdx = actualBottom + offset
                        if frameIdx >= startTop + 1 && frameIdx < candidate {
                            sampleFrames.insert(frameIdx)
                        }
                    }
                    
                    // Sort and display
                    let sortedSamples = Array(sampleFrames).sorted()
                    print("  - Raw vs Smoothed Heights (sampled across rep range):")
                    for frameIdx in sortedSamples {
                        guard frameIdx < poses.count && frameIdx < rawHeights.count && frameIdx < smoothedHeights.count else { continue }
                        let originalFrame = poses[frameIdx].frameIndex
                        let rawHeight = rawHeights[frameIdx]
                        let smoothedHeight = smoothedHeights[frameIdx]
                        let smoothingDiff = smoothedHeight - rawHeight
                        
                        var markers: [String] = []
                        if frameIdx == actualBottom {
                            markers.append("DETECTED_BOTTOM")
                        }
                        if let smoothedBottom = bottomRange.min(by: { smoothedHeights[$0] < smoothedHeights[$1] }), frameIdx == smoothedBottom {
                            markers.append("SMOOTHED_MIN")
                        }
                        if frameIdx == startTop + 1 {
                            markers.append("START")
                        }
                        if frameIdx == candidate - 1 {
                            markers.append("END")
                        }
                        
                        let markerStr = markers.isEmpty ? "" : " [\(markers.joined(separator: ", "))]"
                        print("    Frame \(originalFrame) (filtered \(frameIdx)): raw=\(String(format: "%.3f", rawHeight)), smoothed=\(String(format: "%.3f", smoothedHeight)), diff=\(String(format: "%+.3f", smoothingDiff))\(markerStr)")
                    }
                    
                    // Find and highlight the true raw minimum in the rep range
                    if let trueRawBottom = bottomRange.min(by: { rawHeights[$0] < rawHeights[$1] }) {
                        let trueRawBottomFrame = poses[trueRawBottom].frameIndex
                        let trueRawBottomHeight = rawHeights[trueRawBottom]
                        let smoothedAtTrueRawBottom = smoothedHeights[trueRawBottom]
                        print("  - True raw minimum in rep range: filtered \(trueRawBottom) (original frame \(trueRawBottomFrame))")
                        print("    Raw height=\(String(format: "%.3f", trueRawBottomHeight)), Smoothed height=\(String(format: "%.3f", smoothedAtTrueRawBottom))")
                        if trueRawBottom != actualBottom {
                            let frameDiff = abs(trueRawBottom - actualBottom)
                            let originalFrameDiff = abs(trueRawBottomFrame - poses[actualBottom].frameIndex)
                            print("    ⚠️  MISMATCH: Detected bottom is \(frameDiff) filtered frames (\(originalFrameDiff) original frames) away from true raw minimum!")
                        }
                    }
                    
                    // Log smoothed heights for key frames: start, around detected bottom, and end
                    let keyFrames: [Int] = [
                        startTop + 1,  // Start of descent
                        foundBottom - 5, foundBottom - 2, foundBottom, foundBottom + 2, foundBottom + 5,  // Around detected bottom
                        candidate - 1  // End of range
                    ].filter { $0 >= startTop + 1 && $0 < candidate && $0 < poses.count }
                    
                    print("  - Smoothed heights at key frames (raw → smoothed):")
                    for frameIdx in keyFrames {
                        guard frameIdx < poses.count else { continue }
                        let originalFrame = poses[frameIdx].frameIndex
                        let smoothedHeight = smoothedHeights[frameIdx]
                        
                        // Get raw height for this frame
                        let (leftHip, rightHip) = PoseAnalysisHelpers.extractBilateralKeypoints(
                            leftName: "leftHip",
                            rightName: "rightHip",
                            from: poses[frameIdx]
                        )
                        let rawHeight = PoseAnalysisHelpers.averagePosition(leftHip, rightHip)?.y ?? 0.0
                        
                        let marker = frameIdx == actualBottom ? " <-- MINIMUM (smoothed)" : ""
                        let smoothingDiff = smoothedHeight - Double(rawHeight)
                        print("    - Filtered \(frameIdx) (original \(originalFrame)): raw=\(String(format: "%.3f", Double(rawHeight))), smoothed=\(String(format: "%.3f", smoothedHeight)) (diff=\(String(format: "%+.3f", smoothingDiff)))\(marker)")
                    }
                    
                    // ENHANCED DEBUGGING: Smoothing Effect Analysis
                    print("🔍 detectReps: Smoothing Effect Analysis for Rep \(repNumber + 1):")
                    
                    // Compare smoothed minimum vs raw minimum locations
                    if let rawMinInRange = bottomRange.min(by: { rawHeights[$0] < rawHeights[$1] }) {
                        let rawMinFrame = poses[rawMinInRange].frameIndex
                        let rawMinHeight = rawHeights[rawMinInRange]
                        let smoothedAtRawMin = smoothedHeights[rawMinInRange]
                        
                        let smoothedMinFrame = poses[smoothedBottom].frameIndex
                        let frameOffset = rawMinInRange - smoothedBottom
                        let originalFrameOffset = rawMinFrame - smoothedMinFrame
                        
                        print("  - Minimum Location Comparison:")
                        print("    Smoothed minimum: filtered \(smoothedBottom) (original \(smoothedMinFrame)), height=\(String(format: "%.3f", smoothedBottomHeight))")
                        print("    Raw minimum: filtered \(rawMinInRange) (original \(rawMinFrame)), height=\(String(format: "%.3f", rawMinHeight))")
                        print("    Offset: \(frameOffset) filtered frames (\(originalFrameOffset) original frames)")
                        if frameOffset != 0 {
                            print("    ⚠️  Smoothing shifted minimum by \(abs(frameOffset)) frames (\(frameOffset > 0 ? "later" : "earlier"))")
                        }
                        print("    Smoothed value at raw minimum location: \(String(format: "%.3f", smoothedAtRawMin))")
                        print("    Smoothing effect at raw minimum: \(String(format: "%+.3f", smoothedAtRawMin - rawMinHeight))")
                    }
                    
                    // Show smoothing window details for detected bottom
                    if actualBottom >= 2 && actualBottom < smoothedHeights.count - 2 {
                        let smoothingWindowSize = 5  // Same as used in smoothValues
                        let windowStart = max(0, actualBottom - smoothingWindowSize / 2)
                        let windowEnd = min(poses.count, actualBottom + smoothingWindowSize / 2 + 1)
                        
                        print("  - Smoothing Window Analysis at Detected Bottom (filtered \(actualBottom), original frame \(poses[actualBottom].frameIndex)):")
                        print("    Window size: \(smoothingWindowSize) frames (indices \(windowStart)..<\(windowEnd))")
                        
                        var rawWindowValues: [(index: Int, frame: Int, raw: Double, smoothed: Double)] = []
                        for idx in windowStart..<windowEnd {
                            guard idx < poses.count && idx < rawHeights.count && idx < smoothedHeights.count else { continue }
                            rawWindowValues.append((idx, poses[idx].frameIndex, rawHeights[idx], smoothedHeights[idx]))
                        }
                        
                        print("    Raw values in smoothing window:")
                        for (idx, frame, raw, smoothed) in rawWindowValues {
                            let marker = idx == actualBottom ? " <-- CENTER" : ""
                            print("      Filtered \(idx) (original \(frame)): raw=\(String(format: "%.3f", raw)), smoothed=\(String(format: "%.3f", smoothed)), diff=\(String(format: "%+.3f", smoothed - raw))\(marker)")
                        }
                        
                        if !rawWindowValues.isEmpty {
                            let windowRawAvg = rawWindowValues.map { $0.raw }.reduce(0, +) / Double(rawWindowValues.count)
                            print("    Window raw average: \(String(format: "%.3f", windowRawAvg))")
                            print("    Smoothed result at center: \(String(format: "%.3f", actualBottomHeight))")
                            print("    Smoothing effect: \(String(format: "%+.3f", actualBottomHeight - windowRawAvg))")
                        }
                    }
                    
                    // Show smoothing effect in the true bottom region (if different from detected)
                    if let trueRawBottom = bottomRange.min(by: { rawHeights[$0] < rawHeights[$1] }), trueRawBottom != actualBottom {
                        let trueRawBottomFrame = poses[trueRawBottom].frameIndex
                        let smoothingWindowSize = 5
                        let windowStart = max(0, trueRawBottom - smoothingWindowSize / 2)
                        let windowEnd = min(poses.count, trueRawBottom + smoothingWindowSize / 2 + 1)
                        
                        print("  - Smoothing Window Analysis at True Raw Minimum (filtered \(trueRawBottom), original frame \(trueRawBottomFrame)):")
                        print("    Window size: \(smoothingWindowSize) frames (indices \(windowStart)..<\(windowEnd))")
                        
                        var trueBottomWindowValues: [(index: Int, frame: Int, raw: Double, smoothed: Double)] = []
                        for idx in windowStart..<windowEnd {
                            guard idx < poses.count && idx < rawHeights.count && idx < smoothedHeights.count else { continue }
                            trueBottomWindowValues.append((idx, poses[idx].frameIndex, rawHeights[idx], smoothedHeights[idx]))
                        }
                        
                        print("    Raw values in smoothing window:")
                        for (idx, frame, raw, smoothed) in trueBottomWindowValues {
                            let marker = idx == trueRawBottom ? " <-- CENTER" : ""
                            print("      Filtered \(idx) (original \(frame)): raw=\(String(format: "%.3f", raw)), smoothed=\(String(format: "%.3f", smoothed)), diff=\(String(format: "%+.3f", smoothed - raw))\(marker)")
                        }
                        
                        if !trueBottomWindowValues.isEmpty {
                            let windowRawAvg = trueBottomWindowValues.map { $0.raw }.reduce(0, +) / Double(trueBottomWindowValues.count)
                            let smoothedAtTrueBottom = smoothedHeights[trueRawBottom]
                            print("    Window raw average: \(String(format: "%.3f", windowRawAvg))")
                            print("    Smoothed result at center: \(String(format: "%.3f", smoothedAtTrueBottom))")
                            print("    Smoothing effect: \(String(format: "%+.3f", smoothedAtTrueBottom - windowRawAvg))")
                            print("    ⚠️  This is the true bottom region, but smoothing may have shifted the minimum earlier!")
                        }
                    }
                    
                    print("🔍 detectReps: Using next top candidate \(candidate) as rep end, found bottom at \(actualBottom) between startTop \(startTop) and candidate")
                    
                    // ENHANCED DEBUGGING: Rep-Specific Frame-by-Frame Descent Analysis
                    // Special detailed analysis for Rep 3 (or any rep in problematic range)
                    let repStartOriginalFrame = poses[startTop + 1].frameIndex
                    let repEndOriginalFrame = poses[min(candidate - 1, poses.count - 1)].frameIndex
                    let isRep3 = repNumber == 2  // Rep 3 is repNumber 2 (0-indexed)
                    let isProblematicRange = repStartOriginalFrame >= 300 && repEndOriginalFrame <= 430
                    
                    if isRep3 || isProblematicRange {
                        print("🔍 detectReps: DETAILED DESCENT ANALYSIS for Rep \(repNumber + 1) (original frames \(repStartOriginalFrame)-\(repEndOriginalFrame)):")
                        
                        // Analyze descent phase frame-by-frame
                        let descentStart = startTop + 1
                        let descentEnd = actualBottom
                        let descentRange = descentStart..<min(descentEnd + 20, candidate)  // Include some frames after detected bottom
                        
                        print("  - Descent Phase Analysis (filtered indices \(descentStart)..<\(min(descentEnd + 20, candidate))):")
                        
                        // Sample every 5th frame during descent, plus frames around detected bottom
                        var analysisFrames: Set<Int> = []
                        for i in stride(from: descentStart, to: min(descentEnd + 20, candidate), by: 5) {
                            analysisFrames.insert(i)
                        }
                        // Add frames around detected bottom
                        for offset in -10...10 {
                            let frameIdx = actualBottom + offset
                            if frameIdx >= descentStart && frameIdx < candidate {
                                analysisFrames.insert(frameIdx)
                            }
                        }
                        // Add frames around true raw minimum if different
                        if let trueRawBottom = bottomRange.min(by: { rawHeights[$0] < rawHeights[$1] }), trueRawBottom != actualBottom {
                            for offset in -10...10 {
                                let frameIdx = trueRawBottom + offset
                                if frameIdx >= descentStart && frameIdx < candidate {
                                    analysisFrames.insert(frameIdx)
                                }
                            }
                        }
                        
                        let sortedAnalysisFrames = Array(analysisFrames).sorted()
                        
                        print("  - Frame-by-Frame Descent Data (raw height, smoothed height, hip vs knee):")
                        for frameIdx in sortedAnalysisFrames {
                            guard frameIdx < poses.count && frameIdx < rawHeights.count && frameIdx < smoothedHeights.count else { continue }
                            
                            let originalFrame = poses[frameIdx].frameIndex
                            let rawHeight = rawHeights[frameIdx]
                            let smoothedHeight = smoothedHeights[frameIdx]
                            
                            // Check if hips are below knees at this frame
                            let pose = poses[frameIdx]
                            let (leftHip, rightHip) = PoseAnalysisHelpers.extractBilateralKeypoints(
                                leftName: "leftHip",
                                rightName: "rightHip",
                                from: pose
                            )
                            let (leftKnee, rightKnee) = PoseAnalysisHelpers.extractBilateralKeypoints(
                                leftName: "leftKnee",
                                rightName: "rightKnee",
                                from: pose
                            )
                            
                            var hipBelowKnee = false
                            var hipKneeInfo = ""
                            if let leftHipY = leftHip?.position.y, let leftKneeY = leftKnee?.position.y {
                                if leftHipY < leftKneeY {
                                    hipBelowKnee = true
                                    hipKneeInfo = "L-hip<L-knee"
                                }
                            }
                            if !hipBelowKnee, let rightHipY = rightHip?.position.y, let rightKneeY = rightKnee?.position.y {
                                if rightHipY < rightKneeY {
                                    hipBelowKnee = true
                                    hipKneeInfo = "R-hip<R-knee"
                                }
                            }
                            if !hipBelowKnee {
                                if let leftHipY = leftHip?.position.y, let rightKneeY = rightKnee?.position.y, leftHipY < rightKneeY {
                                    hipBelowKnee = true
                                    hipKneeInfo = "L-hip<R-knee"
                                } else if let rightHipY = rightHip?.position.y, let leftKneeY = leftKnee?.position.y, rightHipY < leftKneeY {
                                    hipBelowKnee = true
                                    hipKneeInfo = "R-hip<L-knee"
                                }
                            }
                            
                            var markers: [String] = []
                            if frameIdx == actualBottom {
                                markers.append("DETECTED_BOTTOM")
                            }
                            if let smoothedBottom = bottomRange.min(by: { smoothedHeights[$0] < smoothedHeights[$1] }), frameIdx == smoothedBottom {
                                markers.append("SMOOTHED_MIN")
                            }
                            if let trueRawBottom = bottomRange.min(by: { rawHeights[$0] < rawHeights[$1] }), frameIdx == trueRawBottom {
                                markers.append("TRUE_RAW_MIN")
                            }
                            if hipBelowKnee {
                                markers.append("HIPS_BELOW_KNEES")
                            }
                            
                            let markerStr = markers.isEmpty ? "" : " [\(markers.joined(separator: ", "))]"
                            let hipKneeStr = hipBelowKnee ? " ✓ \(hipKneeInfo)" : ""
                            print("    Frame \(originalFrame) (filtered \(frameIdx)): raw=\(String(format: "%.3f", rawHeight)), smoothed=\(String(format: "%.3f", smoothedHeight)), diff=\(String(format: "%+.3f", smoothedHeight - rawHeight))\(hipKneeStr)\(markerStr)")
                        }
                        
                        // Summary: Find frames where hips are below knees
                        var framesWithHipsBelowKnees: [Int] = []
                        for frameIdx in descentStart..<candidate {
                            guard frameIdx < poses.count else { continue }
                            let pose = poses[frameIdx]
                            let (leftHip, rightHip) = PoseAnalysisHelpers.extractBilateralKeypoints(
                                leftName: "leftHip",
                                rightName: "rightHip",
                                from: pose
                            )
                            let (leftKnee, rightKnee) = PoseAnalysisHelpers.extractBilateralKeypoints(
                                leftName: "leftKnee",
                                rightName: "rightKnee",
                                from: pose
                            )
                            
                            var isBelow = false
                            if let leftHipY = leftHip?.position.y {
                                if let leftKneeY = leftKnee?.position.y, leftHipY < leftKneeY {
                                    isBelow = true
                                } else if let rightKneeY = rightKnee?.position.y, leftHipY < rightKneeY {
                                    isBelow = true
                                }
                            }
                            if !isBelow, let rightHipY = rightHip?.position.y {
                                if let rightKneeY = rightKnee?.position.y, rightHipY < rightKneeY {
                                    isBelow = true
                                } else if let leftKneeY = leftKnee?.position.y, rightHipY < leftKneeY {
                                    isBelow = true
                                }
                            }
                            
                            if isBelow {
                                framesWithHipsBelowKnees.append(frameIdx)
                            }
                        }
                        
                        if !framesWithHipsBelowKnees.isEmpty {
                            let firstBelowFrame = poses[framesWithHipsBelowKnees.first!].frameIndex
                            let lastBelowFrame = poses[framesWithHipsBelowKnees.last!].frameIndex
                            print("  - Frames with hips below knees: \(framesWithHipsBelowKnees.count) frames")
                            print("    First: filtered \(framesWithHipsBelowKnees.first!) (original \(firstBelowFrame))")
                            print("    Last: filtered \(framesWithHipsBelowKnees.last!) (original \(lastBelowFrame))")
                            print("    Range: original frames \(firstBelowFrame)-\(lastBelowFrame)")
                            
                            let detectedBottomFrame = poses[actualBottom].frameIndex
                            if detectedBottomFrame < firstBelowFrame {
                                print("    ⚠️  PROBLEM: Detected bottom (frame \(detectedBottomFrame)) is BEFORE hips go below knees (starts at frame \(firstBelowFrame))!")
                                print("    ⚠️  Detected bottom is \(firstBelowFrame - detectedBottomFrame) frames too early!")
                            } else if detectedBottomFrame > lastBelowFrame {
                                print("    ⚠️  Detected bottom (frame \(detectedBottomFrame)) is AFTER hips go below knees (ends at frame \(lastBelowFrame))")
                            } else {
                                print("    ✓ Detected bottom (frame \(detectedBottomFrame)) is within the hips-below-knees range")
                            }
                        } else {
                            print("  - ⚠️  No frames found with hips below knees in this rep range")
                        }
                    }
                } else {
                    // If no bottom found in range, use the next bottom after startTop
                    // This handles edge cases where bottom detection missed a bottom
                    actualBottom = nextBottom
                    actualBottomHeight = smoothedHeights[nextBottom]
                    print("🔍 detectReps: Using next top candidate \(candidate) as rep end, no bottom found in range, using nextBottom \(nextBottom)")
                }
            } else {
                // No more tops - this is the last rep
                // Find next top after bottom, or use end of sequence
                nextTop = tops.first(where: { $0 > nextBottom }) ?? poses.count - 1
                actualBottom = nextBottom
                actualBottomHeight = smoothedHeights[nextBottom]
            }
            
            // Get the starting top height for depth calculation (already declared above)
            // startTopHeight is already available from the validation section above
            
            // Calculate depthChange as relative percentage of starting height
            // Since Y decreases downward, depth = top - bottom (positive value)
            let absoluteDepthChange = startTopHeight - actualBottomHeight
            let depthChange = startTopHeight > 0 ? absoluteDepthChange / startTopHeight : absoluteDepthChange
            let reachedDepth = depthChange > minDepthThreshold
            
            // Check if returned to starting height (within threshold)
            let endHeight = nextTop < smoothedHeights.count ? smoothedHeights[nextTop] : (smoothedHeights.last ?? startHeight)
            let repRange = abs(startTopHeight - actualBottomHeight)
            let tolerance = max(0.02, repRange * 0.03)
            let returnedToStart = abs(endHeight - setupMedianHeight) <= tolerance
            
            let isFullRep = reachedDepth && returnedToStart
            
            // Only create rep if it has minimum duration (at least 10 frames) and significant movement
            let cycleDuration = nextTop - cycleStart
            let hasSignificantMovement = depthChange > minDepthThreshold * 0.5  // At least half the threshold
            
            if cycleDuration >= 10 && hasSignificantMovement {
                let originalStartFrame = poses[cycleStart].frameIndex
                let originalEndFrame = poses[min(nextTop, poses.count - 1)].frameIndex
                let originalBottomFrame = poses[actualBottom].frameIndex
                
                reps.append(SquatRep(
                    repNumber: repNumber,
                    startFrame: cycleStart,
                    endFrame: min(nextTop, poses.count - 1),
                    startTime: poses[cycleStart].timestamp.timeIntervalSince1970,
                    endTime: poses[min(nextTop, poses.count - 1)].timestamp.timeIntervalSince1970,
                    isFullRep: isFullRep,
                    bottomFrame: actualBottom,
                    bottomTime: poses[actualBottom].timestamp.timeIntervalSince1970,
                    reachedDepth: reachedDepth,
                    returnedToStart: returnedToStart
                ))
                
                print("🔍 detectReps: Created rep \(repNumber): filtered frames \(cycleStart)-\(min(nextTop, poses.count - 1)) (original frames \(originalStartFrame)-\(originalEndFrame)), bottom at filtered \(actualBottom) (original \(originalBottomFrame))")
                print("  - Heights: startTop=\(String(format: "%.3f", startTopHeight)), bottom=\(String(format: "%.3f", actualBottomHeight)), startHeight=\(String(format: "%.3f", startHeight))")
                print("  - Depth: absolute=\(String(format: "%.3f", absoluteDepthChange)), relative=\(String(format: "%.1f", depthChange * 100))%, threshold=\(String(format: "%.1f", minDepthThreshold * 100))%")
                
                repNumber += 1
            }
            
            // Move to next cycle - start from the next top
            cycleStart = nextTop
            
            // Find the index of nextTop in the tops array, then process it as the start of next rep
            if let currentTopIndexInArray = tops.firstIndex(of: nextTop) {
                // Set currentTopIndex to nextTop itself, so next iteration processes it as startTop
                // This ensures each top serves as both the end of one rep and the start of the next
                currentTopIndex = currentTopIndexInArray
                
                // Check if there's another top after this one
                let nextTopIndexInArray = currentTopIndexInArray + 1
                if nextTopIndexInArray < tops.count {
                    // There's another top, continue loop to process nextTop as start of next rep
                    print("🔍 detectReps: Will process top at index \(nextTop) as start of rep \(repNumber + 1)")
                } else {
                    // No more tops in array, but check if there's a final rep after this top
                    // This handles the case where the last rep ends at the end of the sequence
                    let originalTopFrame = nextTop < poses.count ? poses[nextTop].frameIndex : -1
                    print("🔍 detectReps: At last top (filtered \(nextTop), original frame \(originalTopFrame)), checking for final rep")
                    
                    // Check if there's significant movement after this top that could form another rep
                    // Always check, regardless of remaining frame count - let the rep creation logic handle duration requirements
                    let endFrame = poses.count - 1
                    let remainingFrames = endFrame - nextTop
                    let originalEndFrame = endFrame < poses.count ? poses[endFrame].frameIndex : -1
                    print("🔍 detectReps: endFrame=filtered \(endFrame) (original \(originalEndFrame)), nextTop=filtered \(nextTop) (original \(originalTopFrame)), remaining frames=\(remainingFrames)")
                    
                    // Find the deepest point (bottom) after this top
                    // Since Y decreases downward, bottom = minimum Y value
                    let remainingFrameRange = nextTop..<smoothedHeights.count
                    if let bottomIndex = remainingFrameRange.min(by: { smoothedHeights[$0] < smoothedHeights[$1] }) {
                        let bottomHeight = smoothedHeights[bottomIndex]
                        let startTopHeight = smoothedHeights[nextTop]
                        // Calculate depthChange as relative percentage of starting height
                        // Since Y decreases downward, depth = top - bottom (positive value)
                        let absoluteDepthChange = startTopHeight - bottomHeight
                        let depthChange = startTopHeight > 0 ? absoluteDepthChange / startTopHeight : absoluteDepthChange
                        let reachedDepth = depthChange > minDepthThreshold
                        
                        let originalBottomFrame = bottomIndex < poses.count ? poses[bottomIndex].frameIndex : -1
                        let originalTopFrame = nextTop < poses.count ? poses[nextTop].frameIndex : -1
                        print("🔍 detectReps: Found bottom at filtered index \(bottomIndex) (original frame \(originalBottomFrame))")
                        print("  - Heights: startTop=\(String(format: "%.3f", startTopHeight)), bottom=\(String(format: "%.3f", bottomHeight)), startHeight=\(String(format: "%.3f", startHeight))")
                        print("  - Depth: absolute=\(String(format: "%.3f", absoluteDepthChange)), relative=\(String(format: "%.1f", depthChange * 100))%, threshold=\(String(format: "%.1f", minDepthThreshold * 100))%")
                        
                        // Check if returned to starting height
                        let endHeight = smoothedHeights[endFrame]
                        let repRange = abs(startTopHeight - bottomHeight)
                        let tolerance = max(0.02, repRange * 0.03)
                        let returnedToStart = abs(endHeight - setupMedianHeight) <= tolerance
                        let isFullRep = reachedDepth && returnedToStart
                        
                        let cycleDuration = endFrame - nextTop
                        let hasSignificantMovement = depthChange > minDepthThreshold * 0.5
                        
                        let originalStartFrame = nextTop < poses.count ? poses[nextTop].frameIndex : -1
                        let originalEndFrame = endFrame < poses.count ? poses[endFrame].frameIndex : -1
                        print("🔍 detectReps: cycleDuration=\(cycleDuration), hasSignificantMovement=\(hasSignificantMovement), reachedDepth=\(reachedDepth)")
                        print("  - Rep range: filtered \(nextTop)-\(endFrame) (original frames \(originalStartFrame)-\(originalEndFrame))")
                        
                        // Create rep if it meets duration and movement criteria
                        // Duration check ensures we don't create reps from tiny movements
                        if cycleDuration >= 10 && hasSignificantMovement {
                            reps.append(SquatRep(
                                repNumber: repNumber,
                                startFrame: nextTop,
                                endFrame: endFrame,
                                startTime: poses[nextTop].timestamp.timeIntervalSince1970,
                                endTime: poses[endFrame].timestamp.timeIntervalSince1970,
                                isFullRep: isFullRep,
                                bottomFrame: bottomIndex,
                                bottomTime: poses[bottomIndex].timestamp.timeIntervalSince1970,
                                reachedDepth: reachedDepth,
                                returnedToStart: returnedToStart
                            ))
                            
                            print("🔍 detectReps: Created final rep \(repNumber): frames \(nextTop)-\(endFrame), bottom at \(bottomIndex), depthChange=\(String(format: "%.3f", depthChange))")
                        } else {
                            print("🔍 detectReps: Final rep doesn't meet criteria (duration=\(cycleDuration) >= 10: \(cycleDuration >= 10), movement=\(String(format: "%.3f", depthChange)) > \(String(format: "%.3f", minDepthThreshold * 0.5)): \(hasSignificantMovement))")
                        }
                    } else {
                        print("🔍 detectReps: No bottom found after last top (remainingFrameRange: \(remainingFrameRange))")
                    }
                    
                    print("🔍 detectReps: No more tops found, detected \(reps.count) reps")
                    break
                }
            } else {
                // nextTop is not in the tops array (it's poses.count - 1), look for next top after nextBottom
                if let nextTopAfterBottom = tops.first(where: { $0 > nextBottom }) {
                    if let nextTopIndexInArray = tops.firstIndex(of: nextTopAfterBottom) {
                        currentTopIndex = nextTopIndexInArray
                        cycleStart = nextTopAfterBottom - 1  // Start slightly before the top
                        let originalTopFrame = nextTopAfterBottom < poses.count ? poses[nextTopAfterBottom].frameIndex : -1
                        print("🔍 detectReps: Found next top at filtered index \(nextTopAfterBottom) (original frame \(originalTopFrame)) for rep \(repNumber)")
                    } else {
                        break
                    }
                } else {
                    // No more tops found
                    let originalBottomFrame = nextBottom < poses.count ? poses[nextBottom].frameIndex : -1
                    print("🔍 detectReps: No more tops after bottom at filtered \(nextBottom) (original frame \(originalBottomFrame)), detected \(repNumber) reps")
                    break
                }
            }
        }
        
        // If no reps were detected but we have significant movement, create a single rep
        if reps.isEmpty && poses.count >= 10 {
            let startHeightValue = smoothedHeights.first!
            let endHeightValue = smoothedHeights.last!
            let totalAbsoluteChange = abs(endHeightValue - startHeightValue)
            // Calculate as relative percentage
            let totalHeightChange = startHeightValue > 0 ? totalAbsoluteChange / startHeightValue : totalAbsoluteChange
            if totalHeightChange > minDepthThreshold {
                // Single rep covering entire sequence
                let endFrame = poses.count - 1
                // Since Y decreases downward, bottom = minimum Y value
                let bottomIndex = smoothedHeights.enumerated().min(by: { $0.element < $1.element })?.offset ?? endFrame
                let bottomHeight = smoothedHeights[bottomIndex]
                // Calculate depthChange as relative percentage
                // Since Y decreases downward, depth = top - bottom (positive value)
                let absoluteDepthChange = startHeightValue - bottomHeight
                let depthChange = startHeightValue > 0 ? absoluteDepthChange / startHeightValue : absoluteDepthChange
                let reachedDepth = depthChange > minDepthThreshold
                let repRange = abs(startHeightValue - bottomHeight)
                let tolerance = max(0.02, repRange * 0.03)
                let returnedToStart = abs(smoothedHeights[endFrame] - setupMedianHeight) <= tolerance
                
                let originalStartFrame = poses[0].frameIndex
                let originalEndFrame = poses[endFrame].frameIndex
                let originalBottomFrame = poses[bottomIndex].frameIndex
                print("🔍 detectReps: Creating single rep fallback: filtered frames 0-\(endFrame) (original frames \(originalStartFrame)-\(originalEndFrame))")
                print("  - Heights: start=\(String(format: "%.3f", startHeightValue)), bottom=\(String(format: "%.3f", bottomHeight)), end=\(String(format: "%.3f", endHeightValue))")
                print("  - Depth: absolute=\(String(format: "%.3f", absoluteDepthChange)), relative=\(String(format: "%.1f", depthChange * 100))%, threshold=\(String(format: "%.1f", minDepthThreshold * 100))%")
                
                reps.append(SquatRep(
                    repNumber: 1,
                    startFrame: 0,
                    endFrame: endFrame,
                    startTime: poses[0].timestamp.timeIntervalSince1970,
                    endTime: poses[endFrame].timestamp.timeIntervalSince1970,
                    isFullRep: reachedDepth && returnedToStart,
                    bottomFrame: bottomIndex,
                    bottomTime: poses[bottomIndex].timestamp.timeIntervalSince1970,
                    reachedDepth: reachedDepth,
                    returnedToStart: returnedToStart
                ))
            }
        }
        
        // Debug: Log final result with original frame numbers
        print("🔍 detectReps: Final result - detected \(reps.count) reps")
        for rep in reps {
            let originalStartFrame = rep.startFrame < poses.count ? poses[rep.startFrame].frameIndex : -1
            let originalEndFrame = rep.endFrame < poses.count ? poses[rep.endFrame].frameIndex : -1
            let originalBottomFrame = rep.bottomFrame < poses.count ? poses[rep.bottomFrame].frameIndex : -1
            print("  - Rep \(rep.repNumber): filtered frames \(rep.startFrame)-\(rep.endFrame) (original frames \(originalStartFrame)-\(originalEndFrame)), bottom at filtered \(rep.bottomFrame) (original \(originalBottomFrame)), isFullRep=\(rep.isFullRep)")
        }
        
        return reps
    }
    
    // MARK: - Phase Detection
    
    /// Detect squat phases by tracking hip height changes
    static func detectPhases(_ poses: [PoseDetectionResult]) -> [SquatPhase] {
        guard poses.count >= 3 else { return [] }
        
        // Extract hip heights
        let hipHeights = poses.compactMap { pose -> Double? in
            let (leftHip, rightHip) = PoseAnalysisHelpers.extractBilateralKeypoints(
                leftName: "leftHip",
                rightName: "rightHip",
                from: pose
            )
            guard let hipPos = PoseAnalysisHelpers.averagePosition(leftHip, rightHip) else {
                return nil
            }
            return Double(hipPos.y)
        }
        
        guard hipHeights.count == poses.count else { return [] }
        
        // Smooth the data to reduce noise
        let smoothedHeights = PoseAnalysisHelpers.smoothValues(hipHeights, windowSize: 5)
        
        // Find starting height (average of first few frames)
        let startHeight = Array(smoothedHeights.prefix(5)).reduce(0, +) / Double(min(5, smoothedHeights.count))
        
        // Find bottom position (minimum Y value = lowest point, since Y decreases downward)
        guard let bottomIndex = smoothedHeights.enumerated().min(by: { $0.element < $1.element })?.offset else {
            return []
        }
        let bottomHeight = smoothedHeights[bottomIndex]
        
        // Detect phases
        var phases: [SquatPhase] = []
        
        // Setup phase (first 20% or until descent starts)
        let setupEndIndex = max(1, Int(Double(poses.count) * 0.2))
        phases.append(SquatPhase(
            type: .setup,
            startFrame: 0,
            endFrame: setupEndIndex,
            startTime: poses[0].timestamp.timeIntervalSince1970,
            endTime: poses[min(setupEndIndex, poses.count - 1)].timestamp.timeIntervalSince1970
        ))
        
        // Descent phase (from setup end to bottom)
        phases.append(SquatPhase(
            type: .descent,
            startFrame: setupEndIndex,
            endFrame: bottomIndex,
            startTime: poses[setupEndIndex].timestamp.timeIntervalSince1970,
            endTime: poses[bottomIndex].timestamp.timeIntervalSince1970
        ))
        
        // Bottom phase (around the bottom position, ±3 frames)
        let bottomStart = max(0, bottomIndex - 3)
        let bottomEnd = min(poses.count - 1, bottomIndex + 3)
        phases.append(SquatPhase(
            type: .bottom,
            startFrame: bottomStart,
            endFrame: bottomEnd,
            startTime: poses[bottomStart].timestamp.timeIntervalSince1970,
            endTime: poses[bottomEnd].timestamp.timeIntervalSince1970
        ))
        
        // Ascent phase (from bottom to end)
        if bottomEnd < poses.count - 1 {
            phases.append(SquatPhase(
                type: .ascent,
                startFrame: bottomEnd,
                endFrame: poses.count - 1,
                startTime: poses[bottomEnd].timestamp.timeIntervalSince1970,
                endTime: poses[poses.count - 1].timestamp.timeIntervalSince1970
            ))
        }
        
        return phases
    }
    
    // MARK: - Depth Analysis
    
    /// Calculate depth metrics for a single pose
    /// If repStartHeight and repBottomHeight are provided, uses rep-specific heights for depth percentage calculation
    /// Otherwise falls back to global startHeight and minHeight
    static func calculateDepth(_ pose: PoseDetectionResult, startHeight: Double, minHeight: Double, repNumber: Int? = nil, repStartHeight: Double? = nil, repBottomHeight: Double? = nil) -> DepthAnalysis? {
        let (leftHip, rightHip) = PoseAnalysisHelpers.extractBilateralKeypoints(
            leftName: "leftHip",
            rightName: "rightHip",
            from: pose
        )
        let (leftKnee, rightKnee) = PoseAnalysisHelpers.extractBilateralKeypoints(
            leftName: "leftKnee",
            rightName: "rightKnee",
            from: pose
        )
        
        // Extract individual hip and knee Y values
        let leftHipY = leftHip?.position.y
        let rightHipY = rightHip?.position.y
        let leftKneeY = leftKnee?.position.y
        let rightKneeY = rightKnee?.position.y
        
        // Check if any hip point goes below any knee point
        // Since Y decreases downward, hip below knee means hipY < kneeY
        // For side-view videos, one hip might be lower than the other
        var isAtDepth = false
        if let leftHipY = leftHipY {
            if let leftKneeY = leftKneeY, leftHipY < leftKneeY {
                isAtDepth = true
            } else if let rightKneeY = rightKneeY, leftHipY < rightKneeY {
                isAtDepth = true
            }
        }
        if !isAtDepth, let rightHipY = rightHipY {
            if let leftKneeY = leftKneeY, rightHipY < leftKneeY {
                isAtDepth = true
            } else if let rightKneeY = rightKneeY, rightHipY < rightKneeY {
                isAtDepth = true
            }
        }
        
        // For depth percentage calculation, prefer same-side hip and knee when available
        // This handles side-view videos where one leg may be occluded
        // Fall back to average positions if both sides are available (front-view)
        let hipY: Double
        let kneeY: Double
        
        // Try to use same-side keypoints first (left side or right side)
        if let leftHipY = leftHipY, let leftKneeY = leftKneeY {
            // Use left side
            hipY = Double(leftHipY)
            kneeY = Double(leftKneeY)
        } else if let rightHipY = rightHipY, let rightKneeY = rightKneeY {
            // Use right side
            hipY = Double(rightHipY)
            kneeY = Double(rightKneeY)
        } else if let hipPos = PoseAnalysisHelpers.averagePosition(leftHip, rightHip),
                   let kneePos = PoseAnalysisHelpers.averagePosition(leftKnee, rightKnee) {
            // Fall back to average positions (both sides available, front-view)
            hipY = Double(hipPos.y)
            kneeY = Double(kneePos.y)
        } else {
            // No valid hip/knee combination available
            return nil
        }
        
        // Calculate depth percentage relative to knee level
        // 0% = standing (start position), 100% = hip reaches knee level
        // Values >100% are capped at 100% (hip below knee)
        let depthStartY = repStartHeight ?? startHeight
        let depthPercentage: Double
        if hipY < kneeY {
            // Hip is already at or below knee level
            depthPercentage = 100.0
        } else {
            // Calculate how close hip is to knee level
            // Percentage of the way from start position to knee level
            let totalRangeToKnee = depthStartY - kneeY
            guard totalRangeToKnee > 0 else {
                // Edge case: knee is above start (shouldn't happen in normal squat)
                return DepthAnalysis(
                    hipHeight: hipY,
                    kneeHeight: kneeY,
                    isAtDepth: isAtDepth,
                    depthPercentage: 0.0,
                    timestamp: pose.timestamp,
                    repNumber: repNumber
                )
            }
            let currentRange = depthStartY - hipY
            depthPercentage = min(100.0, max(0.0, (currentRange / totalRangeToKnee) * 100))
        }
        
        // Debug: Log depth calculation at bottom of each rep for verification
        // This will be checked in the calling code to only log at rep bottoms
        
        return DepthAnalysis(
            hipHeight: hipY,
            kneeHeight: kneeY,
            isAtDepth: isAtDepth,
            depthPercentage: depthPercentage,
            timestamp: pose.timestamp,
            repNumber: repNumber
        )
    }
    
    // MARK: - Camera Angle Detection

    /// Detect camera angle from pose data.
    ///
    /// Returns a best-effort classification along with a confidence score.
    ///
    /// - Parameters:
    ///   - poseHistory: Full pose sequence (unfiltered).
    /// - Returns:
    ///   - angle: `.side`, `.front`, or `.diagonal`.
    ///   - confidence: 0...1 confidence based on joint visibility + separation margin.
    ///   - medianKneeSeparation: median `abs(leftKnee.x - rightKnee.x)` across frames where both knees are visible.
    ///   - bothSidesFrameRatio: fraction of frames where both knees are visible (minConfidence >= 0.3).
    static func detectCameraAngle(from poseHistory: [PoseDetectionResult]) -> (angle: CameraAngle, confidence: Double, medianKneeSeparation: Double, bothSidesFrameRatio: Double) {
        guard !poseHistory.isEmpty else {
            return (angle: .side, confidence: 0.0, medianKneeSeparation: 0.0, bothSidesFrameRatio: 0.0)
        }

        let minConfidence: Float = 0.3

        var framesWithBothSides = 0
        var framesWithOneSide = 0
        var kneeSeparations: [Double] = []
        kneeSeparations.reserveCapacity(poseHistory.count)

        for pose in poseHistory {
            let leftKnee = PoseAnalysisHelpers.extractKeypoint("leftKnee", from: pose)
            let rightKnee = PoseAnalysisHelpers.extractKeypoint("rightKnee", from: pose)

            let hasLeft = (leftKnee?.confidence ?? 0) >= minConfidence
            let hasRight = (rightKnee?.confidence ?? 0) >= minConfidence

            if hasLeft && hasRight, let l = leftKnee, let r = rightKnee {
                framesWithBothSides += 1
                kneeSeparations.append(abs(Double(l.position.x - r.position.x)))
            } else if hasLeft || hasRight {
                framesWithOneSide += 1
            }
        }

        func median(_ values: [Double]) -> Double? {
            guard !values.isEmpty else { return nil }
            let sorted = values.sorted()
            let mid = sorted.count / 2
            if sorted.count % 2 == 0 {
                return (sorted[mid - 1] + sorted[mid]) / 2.0
            }
            return sorted[mid]
        }

        let total = Double(poseHistory.count)
        let bothSidesFrameRatio = total > 0 ? Double(framesWithBothSides) / total : 0.0
        let oneSideFrameRatio = total > 0 ? Double(framesWithOneSide) / total : 0.0
        let medianKneeSeparation = median(kneeSeparations) ?? 0.0

        // Classification thresholds (normalized coordinates).
        let sideThreshold = 0.08
        let frontThreshold = 0.18

        let angle: CameraAngle
        if framesWithOneSide > framesWithBothSides || medianKneeSeparation < sideThreshold {
            angle = .side
        } else if medianKneeSeparation > frontThreshold {
            angle = .front
        } else {
            angle = .diagonal
        }

        let baseConfidence: Double = {
            switch angle {
            case .side:
                return oneSideFrameRatio
            case .front, .diagonal, .back:
                return bothSidesFrameRatio
            }
        }()

        // Boost as the median separation moves away from the decision boundaries.
        let margin: Double = {
            switch angle {
            case .side:
                let sepMargin = max(0.0, (sideThreshold - medianKneeSeparation) / sideThreshold)
                let visMargin = max(0.0, (oneSideFrameRatio - bothSidesFrameRatio) / 0.5)
                return min(1.0, max(sepMargin, visMargin))
            case .front:
                return min(1.0, max(0.0, (medianKneeSeparation - frontThreshold) / 0.12))
            case .diagonal:
                let low = sideThreshold
                let high = frontThreshold
                guard medianKneeSeparation > low && medianKneeSeparation < high else { return 0.0 }
                let distToBoundary = min(medianKneeSeparation - low, high - medianKneeSeparation)
                let halfBand = (high - low) / 2.0
                return min(1.0, max(0.0, distToBoundary / halfBand))
            case .back:
                return 0.0
            }
        }()

        let confidence = min(1.0, max(0.0, baseConfidence + (0.25 * margin)))

        return (
            angle: angle,
            confidence: confidence,
            medianKneeSeparation: medianKneeSeparation,
            bothSidesFrameRatio: bothSidesFrameRatio
        )
    }

    // MARK: - Knee Angle Analysis
    
    /// Calculate knee angle metrics for a single pose
    /// cameraAngle: The detected camera angle - knee valgus is only valid for front/back views
    static func calculateKneeAngles(_ pose: PoseDetectionResult, repNumber: Int? = nil, cameraAngle: CameraAngle = .side) -> KneeAnalysis? {
        let (leftHip, rightHip) = PoseAnalysisHelpers.extractBilateralKeypoints(
            leftName: "leftHip",
            rightName: "rightHip",
            from: pose
        )
        let (leftKnee, rightKnee) = PoseAnalysisHelpers.extractBilateralKeypoints(
            leftName: "leftKnee",
            rightName: "rightKnee",
            from: pose
        )
        let (leftAnkle, rightAnkle) = PoseAnalysisHelpers.extractBilateralKeypoints(
            leftName: "leftAnkle",
            rightName: "rightAnkle",
            from: pose
        )
        
        // Calculate left knee angle
        var leftAngle: Double?
        if let hip = leftHip, let knee = leftKnee, let ankle = leftAnkle {
            leftAngle = PoseAnalysisHelpers.calculateAngle(
                point1: hip.position,
                point2: knee.position,
                point3: ankle.position
            )
        }
        
        // Calculate right knee angle
        var rightAngle: Double?
        if let hip = rightHip, let knee = rightKnee, let ankle = rightAnkle {
            rightAngle = PoseAnalysisHelpers.calculateAngle(
                point1: hip.position,
                point2: knee.position,
                point3: ankle.position
            )
        }
        
        guard let left = leftAngle ?? rightAngle else { return nil }
        let right = rightAngle ?? leftAngle ?? left
        
        let minAngle = min(left, right)
        let maxAngle = max(left, right)
        let averageAngle = (left + right) / 2
        
        // Calculate knee valgus (knees caving inward).
        // Only valid for front view - skip for side/diagonal views where knees are stacked/foreshortened.
        let kneeValgus: Double
        let hasValgus: Bool
        if cameraAngle != .front {
            kneeValgus = 0
            hasValgus = false
        } else if let leftKnee = leftKnee, let rightKnee = rightKnee,
                  let leftAnkle = leftAnkle, let rightAnkle = rightAnkle {
            let kneeSep = abs(Double(leftKnee.position.x - rightKnee.position.x))
            let ankleSep = abs(Double(leftAnkle.position.x - rightAnkle.position.x))
            let ratio = kneeSep / max(ankleSep, 1e-3)
            kneeValgus = ratio
            hasValgus = ratio < 0.85
        } else {
            kneeValgus = 0
            hasValgus = false
        }
        
        return KneeAnalysis(
            leftAngle: left,
            rightAngle: right,
            minAngle: minAngle,
            maxAngle: maxAngle,
            averageAngle: averageAngle,
            kneeValgus: kneeValgus,
            hasValgus: hasValgus,
            timestamp: pose.timestamp,
            repNumber: repNumber
        )
    }
    
    // MARK: - Score Calculation
    
    /// Calculate overall form score (0-100) based on all reps
    /// Averages per-rep scores to reflect overall set quality
    static func calculateOverallScore(
        reps: [SquatRep],
        depthMetrics: [DepthAnalysis],
        kneeMetrics: [KneeAnalysis],
        formDeviations: [FormDeviationAnalyzer.FormDeviation] = []
    ) -> Double {
        guard !reps.isEmpty else {
            return 0.0
        }
        
        // Pre-group metrics by rep number for O(1) lookups (O(n) operation)
        let depthByRep = Dictionary(grouping: depthMetrics, by: { $0.repNumber ?? 0 })
        let kneeByRep = Dictionary(grouping: kneeMetrics, by: { $0.repNumber ?? 0 })
        let deviationsByRep = Dictionary(grouping: formDeviations, by: { $0.repNumber })
        
        var repScores: [Double] = []
        
        // Calculate score for each rep
        for rep in reps {
            var repScore = 100.0
            
            // Get metrics for this rep using dictionary lookup (O(1))
            let repDepthMetrics = depthByRep[rep.repNumber] ?? []
            let repKneeMetrics = kneeByRep[rep.repNumber] ?? []
            
            // Get worst metrics for this rep (or best available)
            let repWorstDepth = repDepthMetrics.min { $0.depthPercentage < $1.depthPercentage }
            let repWorstKnee = repKneeMetrics.min { $0.minAngle < $1.minAngle }
            
            // Penalize if rep is not full
            if !rep.isFullRep {
                repScore -= 20 // Significant penalty for incomplete range of motion
            }
            
            // Depth scoring (30% weight)
            if let depth = repWorstDepth {
                if depth.isAtDepth {
                    // Full points for proper depth
                } else if depth.depthPercentage > 80 {
                    repScore -= 5 // Slightly shallow
                } else if depth.depthPercentage > 60 {
                    repScore -= 15 // Moderately shallow
                } else {
                    repScore -= 30 // Very shallow
                }
            } else if !repDepthMetrics.isEmpty {
                // Has depth metrics but none selected - use average
                let avgDepth = repDepthMetrics.map { $0.depthPercentage }.reduce(0, +) / Double(repDepthMetrics.count)
                if avgDepth < 60 {
                    repScore -= 30
                } else if avgDepth < 80 {
                    repScore -= 15
                } else {
                    repScore -= 5
                }
            } else {
                repScore -= 10 // Missing depth data
            }
            
            // Knee angle scoring (30% weight)
            // Optional analysis - don't penalize if missing (ankles may not be detected)
            if let knee = repWorstKnee {
                if knee.hasValgus {
                    repScore -= 20 // Knee valgus is dangerous
                }
                if knee.minAngle < 60 {
                    repScore -= 10 // Very deep, but check if controlled
                }
            }
            // No penalty for missing knee data - it's an optional analysis
            
            // Back rounding scoring (40% weight - most important for safety)
            // Only use torsoBias deviations for scoring (torsoInstability, hipShoot, balanceDrift excluded for troubleshooting)
            // Optional analysis - don't penalize if missing (no deviations detected)
            let repDeviations = deviationsByRep[rep.repNumber] ?? []
            let torsoBiasDeviations = repDeviations.filter { $0.type == .torsoBias }
            let worstDeviation = torsoBiasDeviations.max { deviation1, deviation2 in
                // Compare severities: severe > moderate > mild > none
                switch (deviation1.severity, deviation2.severity) {
                case (.severe, _): return false
                case (_, .severe): return true
                case (.moderate, _): return false
                case (_, .moderate): return true
                case (.mild, _): return false
                case (_, .mild): return true
                case (.none, _): return false
                }
            }
            
            if let deviation = worstDeviation {
                // Use biomechanical deviation severity (only torsoBias affects score)
                switch deviation.severity {
                case .severe:
                    repScore -= 40 // Dangerous
                case .moderate:
                    repScore -= 25 // Risky
                case .mild:
                    repScore -= 10 // Needs attention
                case .none:
                    break // Good
                }
            }
            // No penalty for missing back data - it's an optional analysis
            // If no torsoBias deviations exist, back rounding is not analyzed (no penalty)
            // Note: Other deviation types (torsoInstability, hipShoot, balanceDrift) are still logged and shown in feedback
            
            repScores.append(max(0, min(100, repScore)))
        }
        
        // Average all rep scores to get overall score
        let averageScore = repScores.reduce(0, +) / Double(repScores.count)
        return averageScore
    }
    
    // MARK: - Rep Number Assignment Helpers
    
    /// Assign rep number to a depth metric based on nearest rep timestamp
    static func assignRepNumberToDepthMetric(_ metric: DepthAnalysis, reps: [SquatRep]) -> DepthAnalysis? {
        guard metric.repNumber == nil, !reps.isEmpty else {
            return metric
        }
        
        // Find the rep whose time range contains or is closest to the metric's timestamp
        let metricTime = metric.timestamp.timeIntervalSince1970
        let nearestRep = reps.min { rep1, rep2 in
            let dist1 = abs(metricTime - rep1.bottomTime)
            let dist2 = abs(metricTime - rep2.bottomTime)
            return dist1 < dist2
        }
        
        guard let rep = nearestRep else { return metric }
        
        return DepthAnalysis(
            hipHeight: metric.hipHeight,
            kneeHeight: metric.kneeHeight,
            isAtDepth: metric.isAtDepth,
            depthPercentage: metric.depthPercentage,
            timestamp: metric.timestamp,
            repNumber: rep.repNumber
        )
    }
    
    /// Assign rep number to a knee metric based on nearest rep timestamp
    static func assignRepNumberToKneeMetric(_ metric: KneeAnalysis, reps: [SquatRep]) -> KneeAnalysis? {
        guard metric.repNumber == nil, !reps.isEmpty else {
            return metric
        }
        
        // Find the rep whose time range contains or is closest to the metric's timestamp
        let metricTime = metric.timestamp.timeIntervalSince1970
        let nearestRep = reps.min { rep1, rep2 in
            let dist1 = abs(metricTime - rep1.bottomTime)
            let dist2 = abs(metricTime - rep2.bottomTime)
            return dist1 < dist2
        }
        
        guard let rep = nearestRep else { return metric }
        
        return KneeAnalysis(
            leftAngle: metric.leftAngle,
            rightAngle: metric.rightAngle,
            minAngle: metric.minAngle,
            maxAngle: metric.maxAngle,
            averageAngle: metric.averageAngle,
            kneeValgus: metric.kneeValgus,
            hasValgus: metric.hasValgus,
            timestamp: metric.timestamp,
            repNumber: rep.repNumber
        )
    }
    
    /// Assign rep number to a back metric based on nearest rep timestamp
    // MARK: - Feedback Generation
    
    /// Map deviation type to appropriate feedback category
    private static func mapDeviationTypeToCategory(_ type: FormDeviationAnalyzer.DeviationType, severity: BackRoundingSeverity) -> FeedbackCategory {
        switch type {
        case .torsoBias:
            // Torso bias is a posture issue, but severe cases are safety concerns
            return severity == .severe ? .safety : .posture
        case .torsoInstability:
            // Torso instability is dangerous jerky movement - always safety
            return .safety
        case .hipShoot:
            // Hip shoot is a movement control/stability issue
            return .stability
        case .balanceDrift:
            // Balance drift is a stability issue
            return .stability
        }
    }
    
    /// Map deviation severity to feedback severity
    private static func mapDeviationSeverityToFeedbackSeverity(_ severity: BackRoundingSeverity) -> FeedbackSeverity {
        switch severity {
        case .severe:
            return .critical
        case .moderate:
            return .warning
        case .mild:
            return .warning
        case .none:
            return .good // Shouldn't happen, but handle gracefully
        }
    }
    
    /// Generate aggregated feedback from analysis results
    /// Aggregates feedback by category across all reps
    static func generateFeedback(
        poses: [PoseDetectionResult],
        smoothedHeights: [Double],
        phases: [SquatPhase],
        reps: [SquatRep],
        depthMetrics: [DepthAnalysis],
        kneeMetrics: [KneeAnalysis],
        worstDepth: DepthAnalysis?,
        worstKnee: KneeAnalysis?,
        startTime: Date,
        camera: (angle: CameraAngle, confidence: Double, medianKneeSeparation: Double, bothSidesFrameRatio: Double),
        segmentLengths: AnthropometryEstimator.SegmentLengths?,
        formDeviations: [FormDeviationAnalyzer.FormDeviation] = []
    ) -> [FormFeedback] {
        var feedback: [FormFeedback] = []
        
        guard !reps.isEmpty else {
            return feedback
        }
        
        // Pre-group metrics by rep number for O(1) lookups (O(n) operation)
        let depthByRep = Dictionary(grouping: depthMetrics, by: { $0.repNumber ?? 0 })
        let kneeByRep = Dictionary(grouping: kneeMetrics, by: { $0.repNumber ?? 0 })
        let deviationsByRep = Dictionary(grouping: formDeviations, by: { $0.repNumber })
        
        // Helper to convert Date (from metrics) to seconds since video start
        func relativeTimestamp(from date: Date) -> TimeInterval {
            date.timeIntervalSince1970 - startTime.timeIntervalSince1970
        }

        let enableSideChecksV2 = ProcessInfo.processInfo.environment["MOVEAI_ENABLE_SIDE_CHECKS_V2"] == "1"
        let enableFrontChecksV2 = ProcessInfo.processInfo.environment["MOVEAI_ENABLE_FRONT_CHECKS_V2"] == "1"
        let enableDiagonalChecks = ProcessInfo.processInfo.environment["MOVEAI_ENABLE_DIAGONAL_CHECKS"] == "1"

        let sideEligible = camera.angle == .side && camera.confidence >= 0.6
        let frontEligible = camera.angle == .front && camera.confidence >= 0.6
        let diagonalEligible = camera.angle == .diagonal && camera.confidence >= 0.6 && enableDiagonalChecks

#if DEBUG
        if ProcessInfo.processInfo.environment["MOVEAI_SQUAT_DEBUG"] == "1" {
            print("📷 SquatAnalyzer: camera=\(camera.angle.rawValue) confidence=\(camera.confidence) medianKneeSep=\(camera.medianKneeSeparation) bothSidesRatio=\(camera.bothSidesFrameRatio)")
        }
#endif

        let minKeypointConfidence: Float = 0.3

        func keypoint(_ name: String, at frameIndex: Int) -> PoseKeypoint? {
            guard frameIndex >= 0 && frameIndex < poses.count else { return nil }
            guard let kp = PoseAnalysisHelpers.extractKeypoint(name, from: poses[frameIndex]) else { return nil }
            guard kp.confidence >= minKeypointConfidence else { return nil }
            return kp
        }

        func bottomFrameIndices(for rep: SquatRep, threshold: Double = 0.8) -> [Int] {
            guard rep.startFrame >= 0, rep.endFrame < smoothedHeights.count, rep.bottomFrame < smoothedHeights.count else { return [] }

            let repStart = smoothedHeights[rep.startFrame]
            let repBottom = smoothedHeights[rep.bottomFrame]
            let denom = repBottom - repStart
            guard abs(denom) > 1e-6 else { return [rep.bottomFrame] }

            var frames: [Int] = []
            for i in rep.startFrame...rep.endFrame {
                let depth = (smoothedHeights[i] - repStart) / denom
                let clamped = max(0.0, min(1.0, depth))
                if clamped >= threshold {
                    frames.append(i)
                }
            }

            if frames.isEmpty {
                let start = max(rep.startFrame, rep.bottomFrame - 2)
                let end = min(rep.endFrame, rep.bottomFrame + 2)
                frames.append(contentsOf: start...end)
            }

            return frames
        }

        func earlyAscentFrameIndices(for rep: SquatRep, threshold: Double = 0.7) -> [Int] {
            guard rep.startFrame >= 0, rep.endFrame < smoothedHeights.count, rep.bottomFrame < smoothedHeights.count else { return [] }

            let repStart = smoothedHeights[rep.startFrame]
            let repBottom = smoothedHeights[rep.bottomFrame]
            let denom = repBottom - repStart
            guard abs(denom) > 1e-6 else { return [] }

            var frames: [Int] = []
            let startIndex = max(rep.bottomFrame, rep.startFrame)
            for i in startIndex...rep.endFrame {
                let depth = (smoothedHeights[i] - repStart) / denom
                let clamped = max(0.0, min(1.0, depth))
                if clamped >= threshold {
                    frames.append(i)
                } else if i > startIndex {
                    break
                }
            }

            return frames
        }

        func median(_ values: [Double]) -> Double? {
            guard !values.isEmpty else { return nil }
            let sorted = values.sorted()
            let mid = sorted.count / 2
            if sorted.count % 2 == 0 {
                return (sorted[mid - 1] + sorted[mid]) / 2.0
            }
            return sorted[mid]
        }

        // RANGE OF MOTION - Per-rep feedback with exact timestamps
        let totalReps = reps.count
        let partialReps = reps.filter { !$0.isFullRep }
        
        // Get depth metrics grouped by rep (using pre-grouped dictionary)
        var repDepthStatus: [Int: (isAtDepth: Bool, depthPercentage: Double)] = [:]
        for rep in reps {
            let repDepthMetrics = depthByRep[rep.repNumber] ?? []
            // Find the deepest point (maximum depth percentage) for this rep
            if let deepestPoint = repDepthMetrics.max(by: { $0.depthPercentage < $1.depthPercentage }) {
                repDepthStatus[rep.repNumber] = (deepestPoint.isAtDepth, deepestPoint.depthPercentage)
            }
        }
        
        // Count reps with good depth
        // Only use isAtDepth for classification - depthPercentage measures position within rep's range, not knee clearance
        let goodDepthReps = repDepthStatus.filter { $0.value.isAtDepth }.map { $0.key }
        let shallowReps = repDepthStatus.filter { !$0.value.isAtDepth }.map { $0.key }
        
        // Debug: Log depth quality for each rep
        print("🔍 Depth Quality Analysis:")
        for rep in reps.sorted(by: { $0.repNumber < $1.repNumber }) {
            if let depthStatus = repDepthStatus[rep.repNumber] {
                let statusLabel = depthStatus.isAtDepth ? "EXCELLENT" : "SHALLOW"
                print("  - Rep \(rep.repNumber): \(statusLabel) (isAtDepth=\(depthStatus.isAtDepth), depthPercentage=\(String(format: "%.1f", depthStatus.depthPercentage))%), isFullRep=\(rep.isFullRep), reachedDepth=\(rep.reachedDepth), returnedToStart=\(rep.returnedToStart)")
            } else {
                print("  - Rep \(rep.repNumber): NO DEPTH DATA (isFullRep=\(rep.isFullRep), reachedDepth=\(rep.reachedDepth), returnedToStart=\(rep.returnedToStart))")
            }
        }
        print("🔍 Depth Quality Summary: \(goodDepthReps.count) excellent, \(shallowReps.count) shallow out of \(totalReps) total reps")
        
        if sideEligible || diagonalEligible {
            // Per-rep range of motion feedback: one FormFeedback per rep with exact timestamp
        for rep in reps {
            let repDepthMetrics = depthByRep[rep.repNumber] ?? []
            let deepestPoint = repDepthMetrics.max(by: { $0.depthPercentage < $1.depthPercentage })
            let timestamp: TimeInterval
            if let deepest = deepestPoint {
                timestamp = relativeTimestamp(from: deepest.timestamp)
            } else {
                timestamp = rep.bottomTime - startTime.timeIntervalSince1970
            }
            
            if partialReps.contains(where: { $0.repNumber == rep.repNumber }) {
                // Incomplete ROM takes precedence
                feedback.append(FormFeedback(
                    category: .rangeOfMotion,
                    message: "Incomplete range of motion - return to start or reach full depth",
                    severity: totalReps == 1 ? .critical : .warning,
                    timestamp: max(0, timestamp),
                    repNumber: rep.repNumber,
                    issueKind: .squatIncompleteROM,
                    affectedBodyJoints: [.leftHip, .rightHip, .leftKnee, .rightKnee]
                ))
            } else if shallowReps.contains(rep.repNumber) {
                feedback.append(FormFeedback(
                    category: .rangeOfMotion,
                    message: "Need to go deeper - aim to get hip crease below knee level",
                    severity: .warning,
                    timestamp: max(0, timestamp),
                    repNumber: rep.repNumber,
                    issueKind: .squatDepthTooShallow,
                    affectedBodyJoints: [.leftHip, .rightHip, .leftKnee, .rightKnee]
                ))
            }
            // Skip positive feedback for reps with excellent depth
        }
        
        }


        // SIDE VIEW CHECKS (Sagittal Plane) - v2 (feature-gated)
        if enableSideChecksV2 && (sideEligible || diagonalEligible) {
            // Depth inconsistent: set-level feedback (requires at least 3 reps with depth data)
            if reps.count >= 3 {
                var repDepthScores: [(repNumber: Int, reachedDepth: Bool, depthScore: Double, deepestTimestamp: Date?)] = []
                repDepthScores.reserveCapacity(reps.count)

                for rep in reps {
                    guard let status = repDepthStatus[rep.repNumber] else { continue }
                    let deepest = (depthByRep[rep.repNumber] ?? []).max(by: { lhs, rhs in
                        lhs.depthPercentage < rhs.depthPercentage
                    })
                    repDepthScores.append(
                        (repNumber: rep.repNumber, reachedDepth: status.isAtDepth, depthScore: status.depthPercentage, deepestTimestamp: deepest?.timestamp)
                    )
                }

                if repDepthScores.count >= 3 {
                    let reachedCount = repDepthScores.filter { item in
                        item.reachedDepth
                    }.count
                    let mixedOutcomes = reachedCount > 0 && reachedCount < repDepthScores.count

                    let scores = repDepthScores.map { item in
                        item.depthScore
                    }
                    let mean = scores.reduce(0, +) / Double(scores.count)
                    let variance = scores.map { value in
                        let d = value - mean
                        return d * d
                    }.reduce(0, +) / Double(scores.count)
                    let stddev = sqrt(variance)

                    if mixedOutcomes || stddev > 12.0 {
                        if let worst = repDepthScores.min(by: { lhs, rhs in
                            lhs.depthScore < rhs.depthScore
                        }) {
                            let ts: TimeInterval
                            if let deepestDate = worst.deepestTimestamp {
                                ts = relativeTimestamp(from: deepestDate)
                            } else if let worstRep = reps.first(where: { rep in
                                rep.repNumber == worst.repNumber
                            }) {
                                ts = worstRep.bottomTime - startTime.timeIntervalSince1970
                            } else {
                                ts = 0
                            }

                            feedback.append(FormFeedback(
                                category: .rangeOfMotion,
                                message: "Depth inconsistent - aim for consistent depth each rep",
                                severity: .warning,
                                timestamp: max(0, ts),
                                repNumber: nil,
                                issueKind: .squatDepthInconsistent,
                                affectedBodyJoints: [.leftHip, .rightHip, .leftKnee, .rightKnee]
                            ))
                        }
                    }
                }
            }
        }

        if enableSideChecksV2 && sideEligible {

            // Heels lift (ankle-rise proxy; Vision 2D body pose does not expose toe/heel joints)
            let setupFrames = Array(poses.indices.prefix(5))

            func baselineAnkleY(_ ankleName: String) -> Double? {
                var ys: [Double] = []
                ys.reserveCapacity(setupFrames.count)

                for frame in setupFrames {
                    guard let ankle = keypoint(ankleName, at: frame) else { continue }
                    ys.append(Double(ankle.position.y))
                }

                return median(ys)
            }

            let baselineLeftAnkleY = baselineAnkleY("leftAnkle")
            let baselineRightAnkleY = baselineAnkleY("rightAnkle")

            for rep in reps {
                let frames = bottomFrameIndices(for: rep, threshold: 0.8)
                var maxRatio: Double = 0.0
                var worstFrame: Int? = nil

                func considerAnkleLift(ankleName: String, kneeName: String, baselineY: Double?, frame: Int) {
                    guard let baselineY = baselineY else { return }
                    guard let ankle = keypoint(ankleName, at: frame),
                          let knee = keypoint(kneeName, at: frame) else { return }

                    let deltaY = Double(ankle.position.y) - baselineY
                    guard deltaY > 0 else { return }

                    let shinLen = PoseAnalysisHelpers.distance(from: ankle.position, to: knee.position)
                    let ratio = deltaY / max(shinLen, 1e-3)
                    guard ratio.isFinite else { return }

                    if ratio > maxRatio {
                        maxRatio = ratio
                        worstFrame = frame
                    }
                }

                for frame in frames {
                    considerAnkleLift(ankleName: "leftAnkle", kneeName: "leftKnee", baselineY: baselineLeftAnkleY, frame: frame)
                    considerAnkleLift(ankleName: "rightAnkle", kneeName: "rightKnee", baselineY: baselineRightAnkleY, frame: frame)
                }

                guard maxRatio > 0.08, let worstFrame = worstFrame else { continue }

                let severity: FeedbackSeverity = maxRatio > 0.14 ? .critical : .warning
                let ts = relativeTimestamp(from: poses[worstFrame].timestamp)

                feedback.append(FormFeedback(
                    category: .stability,
                    message: "Heels lifted - keep the whole foot down",
                    severity: severity,
                    timestamp: max(0, ts),
                    repNumber: rep.repNumber,
                    issueKind: .squatHeelsLift,
                    affectedBodyJoints: [.leftAnkle, .rightAnkle, .leftKnee, .rightKnee]
                ))
            }

            // Knees stayed back (requires anthropometry)
            if let segmentLengths = segmentLengths {
                let expectedMin = SquatMechanicsSolver.minimumShinAngle(depth: 0.9, segmentLengths: segmentLengths)

                for rep in reps {
                    let frames = bottomFrameIndices(for: rep, threshold: 0.8)
                    var angles: [Double] = []
                    angles.reserveCapacity(frames.count)

                    for frame in frames {
                        if let leftAnkle = keypoint("leftAnkle", at: frame), let leftKnee = keypoint("leftKnee", at: frame) {
                            angles.append(PoseAnalysisHelpers.calculateVerticalAngle(from: leftAnkle.position, to: leftKnee.position))
                        }
                        if let rightAnkle = keypoint("rightAnkle", at: frame), let rightKnee = keypoint("rightKnee", at: frame) {
                            angles.append(PoseAnalysisHelpers.calculateVerticalAngle(from: rightAnkle.position, to: rightKnee.position))
                        }
                    }

                    guard let medianAngle = median(angles) else { continue }

                    let deficit = expectedMin - medianAngle
                    guard deficit > 4.0 else { continue }

                    let severity: FeedbackSeverity = deficit > 10.0 ? .critical : .warning
                    let ts = relativeTimestamp(from: poses[rep.bottomFrame].timestamp)

                    feedback.append(FormFeedback(
                        category: .posture,
                        message: "Knees stayed back - allow knees to travel forward while keeping the whole foot down",
                        severity: severity,
                        timestamp: max(0, ts),
                        repNumber: rep.repNumber,
                        issueKind: .squatKneesStayedBack,
                        affectedBodyJoints: [.leftKnee, .rightKnee, .leftAnkle, .rightAnkle]
                    ))
                }
            }

            // Butt wink (conservative proxy)
            for rep in reps {
                let repDeviations = deviationsByRep[rep.repNumber] ?? []
                let alreadyForwardLean = repDeviations.contains(where: { deviation in
                    deviation.type == .torsoBias && deviation.severity != .none
                })
                guard !alreadyForwardLean else { continue }

                // Only consider reps that reached meaningful depth.
                if let status = repDepthStatus[rep.repNumber], status.depthPercentage < 80.0 {
                    continue
                }

                let repStart = smoothedHeights[rep.startFrame]
                let repBottom = smoothedHeights[rep.bottomFrame]
                let denom = repBottom - repStart
                guard abs(denom) > 1e-6 else { continue }

                func depthFraction(at frame: Int) -> Double {
                    let d = (smoothedHeights[frame] - repStart) / denom
                    return max(0.0, min(1.0, d))
                }

                func torsoAngle(at frame: Int) -> Double? {
                    let leftHip = keypoint("leftHip", at: frame)
                    let rightHip = keypoint("rightHip", at: frame)
                    let leftShoulder = keypoint("leftShoulder", at: frame)
                    let rightShoulder = keypoint("rightShoulder", at: frame)

                    let hipPos = PoseAnalysisHelpers.averagePosition(leftHip, rightHip)
                    let shoulderPos = PoseAnalysisHelpers.averagePosition(leftShoulder, rightShoulder)
                    guard let shoulder = shoulderPos, let hip = hipPos else { return nil }

                    return PoseAnalysisHelpers.calculateVerticalAngle(from: shoulder, to: hip)
                }

                let descentRange = rep.startFrame...rep.bottomFrame
                var best75: (frame: Int, delta: Double)? = nil
                var best90: (frame: Int, delta: Double)? = nil

                for frame in descentRange {
                    let depth = depthFraction(at: frame)

                    let d75 = abs(depth - 0.75)
                    if best75 == nil || d75 < best75!.delta {
                        best75 = (frame: frame, delta: d75)
                    }

                    let d90 = abs(depth - 0.90)
                    if best90 == nil || d90 < best90!.delta {
                        best90 = (frame: frame, delta: d90)
                    }
                }

                guard let f75 = best75?.frame, let f90 = best90?.frame, f75 < f90 else { continue }
                guard let a75 = torsoAngle(at: f75), let a90 = torsoAngle(at: f90) else { continue }

                let deltaTorso = a90 - a75
                guard deltaTorso > 12.0 else { continue }

                let ts = relativeTimestamp(from: poses[rep.bottomFrame].timestamp)
                feedback.append(FormFeedback(
                    category: .posture,
                    message: "Pelvis tucked at the bottom - own a depth you can control",
                    severity: .warning,
                    timestamp: max(0, ts),
                    repNumber: rep.repNumber,
                    issueKind: .squatButtWink,
                    affectedBodyJoints: [.leftHip, .rightHip]
                ))
            }
        }

        // FRONT VIEW CHECKS (Frontal Plane)

        // Knee valgus: front only (diagonal-enabled in Phase 3 with stricter thresholds).
        if frontEligible || diagonalEligible {
            for rep in reps {
                let candidateFrames = bottomFrameIndices(for: rep, threshold: 0.8) + earlyAscentFrameIndices(for: rep, threshold: 0.7)
                let uniqueFrames = Array(Set(candidateFrames)).sorted()

                var ratios: [(frameIndex: Int, ratio: Double)] = []
                ratios.reserveCapacity(uniqueFrames.count)

                for frame in uniqueFrames {
                    guard let leftKnee = keypoint("leftKnee", at: frame),
                          let rightKnee = keypoint("rightKnee", at: frame),
                          let leftAnkle = keypoint("leftAnkle", at: frame),
                          let rightAnkle = keypoint("rightAnkle", at: frame) else {
                        continue
                    }

                    let kneeSep = abs(Double(leftKnee.position.x - rightKnee.position.x))
                    let ankleSep = abs(Double(leftAnkle.position.x - rightAnkle.position.x))
                    let ratio = kneeSep / max(ankleSep, 1e-3)

                    ratios.append((frameIndex: frame, ratio: ratio))
                }

                guard ratios.count >= 5 else { continue }

                let triggerThreshold = diagonalEligible ? 0.75 : 0.85
                let belowCount = ratios.filter { $0.ratio < triggerThreshold }.count
                let fraction = Double(belowCount) / Double(ratios.count)

                guard fraction >= 0.2 else { continue }
                guard let worst = ratios.min(by: { $0.ratio < $1.ratio }), worst.ratio < triggerThreshold else { continue }

                let severity: FeedbackSeverity = worst.ratio < 0.70 ? .critical : .warning
                let timestamp = relativeTimestamp(from: poses[worst.frameIndex].timestamp)

                feedback.append(FormFeedback(
                    category: .safety,
                    message: "Knees caving inward - push knees out to align with toes",
                    severity: severity,
                    timestamp: max(0, timestamp),
                    repNumber: rep.repNumber,
                    issueKind: .squatKneeValgus,
                    affectedBodyJoints: [.leftHip, .rightHip, .leftKnee, .rightKnee]
                ))
            }
        }

        // Hip shift / foot collapse are optional front-view checks.
        if enableFrontChecksV2 && (frontEligible || diagonalEligible) {
            // HIP SHIFT
            let setupFrames = Array(poses.indices.prefix(5))
            var baselineOffsets: [Double] = []
            baselineOffsets.reserveCapacity(setupFrames.count)

            for frame in setupFrames {
                guard let leftHip = keypoint("leftHip", at: frame),
                      let rightHip = keypoint("rightHip", at: frame),
                      let leftAnkle = keypoint("leftAnkle", at: frame),
                      let rightAnkle = keypoint("rightAnkle", at: frame) else {
                    continue
                }

                let hipMidX = (Double(leftHip.position.x) + Double(rightHip.position.x)) / 2.0
                let ankleMidX = (Double(leftAnkle.position.x) + Double(rightAnkle.position.x)) / 2.0
                let stanceWidth = abs(Double(leftAnkle.position.x - rightAnkle.position.x))
                let offset = (hipMidX - ankleMidX) / max(stanceWidth, 1e-3)
                baselineOffsets.append(offset)
            }

            if let baselineOffset = median(baselineOffsets) {
                let warnThreshold = diagonalEligible ? 0.12 : 0.08
                let critThreshold = diagonalEligible ? 0.18 : 0.14

                for rep in reps {
                    let frames = bottomFrameIndices(for: rep, threshold: 0.8)
                    var worstDelta: (frameIndex: Int, value: Double)? = nil

                    for frame in frames {
                        guard let leftHip = keypoint("leftHip", at: frame),
                              let rightHip = keypoint("rightHip", at: frame),
                              let leftAnkle = keypoint("leftAnkle", at: frame),
                              let rightAnkle = keypoint("rightAnkle", at: frame) else {
                            continue
                        }

                        let hipMidX = (Double(leftHip.position.x) + Double(rightHip.position.x)) / 2.0
                        let ankleMidX = (Double(leftAnkle.position.x) + Double(rightAnkle.position.x)) / 2.0
                        let stanceWidth = abs(Double(leftAnkle.position.x - rightAnkle.position.x))
                        let offset = (hipMidX - ankleMidX) / max(stanceWidth, 1e-3)
                        let delta = abs(offset - baselineOffset)

                        if worstDelta == nil || delta > worstDelta!.value {
                            worstDelta = (frameIndex: frame, value: delta)
                        }
                    }

                    guard let worst = worstDelta, worst.value > warnThreshold else { continue }

                    let severity: FeedbackSeverity = worst.value > critThreshold ? .critical : .warning
                    let timestamp = relativeTimestamp(from: poses[worst.frameIndex].timestamp)

                    feedback.append(FormFeedback(
                        category: .stability,
                        message: "Shifted to one side - keep pressure even across both feet",
                        severity: severity,
                        timestamp: max(0, timestamp),
                        repNumber: rep.repNumber,
                        issueKind: .squatHipShift,
                        affectedBodyJoints: [.leftHip, .rightHip, .leftKnee, .rightKnee, .leftAnkle, .rightAnkle]
                    ))
                }
            }
        }

        if enableFrontChecksV2 && frontEligible {
            // FOOT COLLAPSE (ankle-inward proxy; toe keypoints are not available in Vision 2D body pose)
            let setupFrames = Array(poses.indices.prefix(5))

            func baselineAnkleDistance(_ ankleName: String) -> Double? {
                var ankleDistances: [Double] = []
                ankleDistances.reserveCapacity(setupFrames.count)

                for frame in setupFrames {
                    guard let leftHip = keypoint("leftHip", at: frame),
                          let rightHip = keypoint("rightHip", at: frame),
                          let ankle = keypoint(ankleName, at: frame) else {
                        continue
                    }

                    let midX = (Double(leftHip.position.x) + Double(rightHip.position.x)) / 2.0
                    ankleDistances.append(abs(Double(ankle.position.x) - midX))
                }

                guard let ankle0 = median(ankleDistances), ankle0 > 1e-3 else { return nil }
                return ankle0
            }

            let baselineLeft = baselineAnkleDistance("leftAnkle")
            let baselineRight = baselineAnkleDistance("rightAnkle")

            for rep in reps {
                // Evaluate during descent/bottom (depth >= 0.5).
                let frames = bottomFrameIndices(for: rep, threshold: 0.5)

                func evaluateFootCollapse(
                    baseline: Double?,
                    ankleName: String
                ) -> (triggered: Bool, minRatio: Double, worstFrame: Int)? {
                    guard let baseline = baseline else { return nil }

                    var eligible = 0
                    var collapsed = 0
                    var minRatio = 1.0
                    var worstFrame = rep.bottomFrame

                    for frame in frames {
                        guard let leftHip = keypoint("leftHip", at: frame),
                              let rightHip = keypoint("rightHip", at: frame),
                              let ankle = keypoint(ankleName, at: frame) else {
                            continue
                        }

                        let midX = (Double(leftHip.position.x) + Double(rightHip.position.x)) / 2.0
                        let dAnkle = abs(Double(ankle.position.x) - midX)
                        let rAnkle = dAnkle / max(baseline, 1e-3)

                        eligible += 1

                        if rAnkle < minRatio {
                            minRatio = rAnkle
                            worstFrame = frame
                        }

                        if rAnkle < 0.85 {
                            collapsed += 1
                        }
                    }

                    guard eligible >= 5 else { return nil }
                    let fraction = Double(collapsed) / Double(eligible)
                    return (triggered: fraction >= 0.2, minRatio: minRatio, worstFrame: worstFrame)
                }

                let leftEval = evaluateFootCollapse(baseline: baselineLeft, ankleName: "leftAnkle")
                let rightEval = evaluateFootCollapse(baseline: baselineRight, ankleName: "rightAnkle")

                var affected: [BodyJoint] = []
                var worstFrame: Int? = nil
                var minRatio = 1.0

                if let leftEval, leftEval.triggered {
                    affected.append(.leftAnkle)
                    if leftEval.minRatio < minRatio {
                        minRatio = leftEval.minRatio
                        worstFrame = leftEval.worstFrame
                    }
                }

                if let rightEval, rightEval.triggered {
                    affected.append(.rightAnkle)
                    if rightEval.minRatio < minRatio {
                        minRatio = rightEval.minRatio
                        worstFrame = rightEval.worstFrame
                    }
                }

                guard !affected.isEmpty, let worstFrame = worstFrame else { continue }

                let severity: FeedbackSeverity = minRatio < 0.70 ? .critical : .warning
                let timestamp = relativeTimestamp(from: poses[worstFrame].timestamp)

                feedback.append(FormFeedback(
                    category: .stability,
                    message: "Foot lost tripod - keep big toe and heel down",
                    severity: severity,
                    timestamp: max(0, timestamp),
                    repNumber: rep.repNumber,
                    issueKind: .squatFootCollapse,
                    affectedBodyJoints: affected
                ))
            }
        }

        // Debug: Log back rounding summary (for troubleshooting, but don't generate aggregated feedback)
        var severeBackReps: [Int] = []
        var moderateBackReps: [Int] = []
        var mildBackReps: [Int] = []
        var goodBackReps: [Int] = []
        
        for rep in reps {
            let repDeviations = deviationsByRep[rep.repNumber] ?? []
            let worstDeviation = repDeviations.max { deviation1, deviation2 in
                // Compare severities: severe > moderate > mild > none
                switch (deviation1.severity, deviation2.severity) {
                case (.severe, _): return false
                case (_, .severe): return true
                case (.moderate, _): return false
                case (_, .moderate): return true
                case (.mild, _): return false
                case (_, .mild): return true
                case (.none, _): return false
                }
            }
            
            if let deviation = worstDeviation {
                // Log for troubleshooting
                print("🔬 Back rounding for Rep \(rep.repNumber): Using biomechanical analysis - \(deviation.type) (\(deviation.severity.rawValue)), magnitude=\(String(format: "%.1f", deviation.magnitude))")
                
                switch deviation.severity {
                case .severe:
                    severeBackReps.append(rep.repNumber)
                case .moderate:
                    moderateBackReps.append(rep.repNumber)
                case .mild:
                    mildBackReps.append(rep.repNumber)
                case .none:
                    goodBackReps.append(rep.repNumber)
                }
            }
        }
        
        let totalWithBackData = severeBackReps.count + moderateBackReps.count + mildBackReps.count + goodBackReps.count
        print("🔍 Back rounding summary: severe=\(severeBackReps), moderate=\(moderateBackReps), mild=\(mildBackReps), good=\(goodBackReps), totalWithData=\(totalWithBackData), totalReps=\(reps.count)")
        
        // INDIVIDUAL FORM DEVIATION FEEDBACK
        // - Forward lean: torsoBias (side-only).
        // - Brace leak: torsoInstability (side-only, behind side-checks v2 flag).
        if sideEligible {
            for rep in reps {
                let repDeviations = deviationsByRep[rep.repNumber] ?? []
                let filteredDeviations = repDeviations.filter { deviation in
                    switch deviation.type {
                    case .torsoBias:
                        return true
                    case .torsoInstability:
                        return enableSideChecksV2
                    case .hipShoot, .balanceDrift:
                        return false
                    }
                }

                for deviation in filteredDeviations {
                    let category = mapDeviationTypeToCategory(deviation.type, severity: deviation.severity)
                    let feedbackSeverity = mapDeviationSeverityToFeedbackSeverity(deviation.severity)

                    let issueKind: MovementIssueKind? = {
                        switch deviation.type {
                        case .torsoBias:
                            return .squatForwardLean
                        case .torsoInstability:
                            return .squatBraceLeak
                        case .hipShoot, .balanceDrift:
                            return nil
                        }
                    }()

                    guard let kind = issueKind else { continue }

                    let joints: [BodyJoint] = [.leftShoulder, .rightShoulder, .leftHip, .rightHip]

                    let midFrame = (deviation.frameRange.lowerBound + deviation.frameRange.upperBound) / 2
                    let clampedFrame = max(0, min(poses.count - 1, midFrame))
                    let deviationTimestamp = relativeTimestamp(from: poses[clampedFrame].timestamp)

                    let metrics: [FeedbackMetric]? = {
                        switch deviation.type {
                        case .torsoBias:
                            return [FeedbackMetric(kind: .squatTorsoBiasDegrees, value: deviation.magnitude, unit: .degrees, phase: .bottom)]
                        case .torsoInstability:
                            return [FeedbackMetric(kind: .squatTorsoInstabilityDegrees, value: deviation.magnitude, unit: .degrees)]
                        case .hipShoot, .balanceDrift:
                            return nil
                        }
                    }()

                    feedback.append(FormFeedback(
                        category: category,
                        message: deviation.message,
                        severity: feedbackSeverity,
                        timestamp: max(0, deviationTimestamp),
                        repNumber: rep.repNumber,
                        issueKind: kind,
                        metrics: metrics,
                        affectedBodyJoints: joints
                    ))
                }
            }
        }


        return feedback
    }
    
    // MARK: - Helper Methods
    
    /// Get the starting hip height (average of first few frames)
    private static func getStartingHipHeight(_ poses: [PoseDetectionResult]) -> Double {
        let startPoses = Array(poses.prefix(5))
        let heights = startPoses.compactMap { pose -> Double? in
            let (leftHip, rightHip) = PoseAnalysisHelpers.extractBilateralKeypoints(
                leftName: "leftHip",
                rightName: "rightHip",
                from: pose
            )
            guard let hipPos = PoseAnalysisHelpers.averagePosition(leftHip, rightHip) else {
                return nil
            }
            return Double(hipPos.y)
        }
        
        return heights.isEmpty ? 0.5 : heights.reduce(0, +) / Double(heights.count)
    }
    
    /// Get the minimum hip height (lowest point reached)
    private static func getMinimumHipHeight(_ poses: [PoseDetectionResult]) -> Double {
        let heights = poses.compactMap { pose -> Double? in
            let (leftHip, rightHip) = PoseAnalysisHelpers.extractBilateralKeypoints(
                leftName: "leftHip",
                rightName: "rightHip",
                from: pose
            )
            guard let hipPos = PoseAnalysisHelpers.averagePosition(leftHip, rightHip) else {
                return nil
            }
            return Double(hipPos.y)
        }
        
        return heights.min() ?? 0.8 // Default to 80% if no data
    }
    
    // MARK: - Error Detection Helpers
    
    /// Find keypoints that are missing across all poses
    /// Uses case-insensitive matching to handle any naming inconsistencies
    private static func findMissingKeypoints(
        in poses: [PoseDetectionResult],
        required: [String]
    ) -> [String] {
        var foundKeypoints = Set<String>()
        
        for pose in poses {
            for keypoint in pose.keypoints {
                // Use lowercase for case-insensitive matching
                foundKeypoints.insert(keypoint.name.lowercased())
            }
        }
        
        // Debug logging to help diagnose keypoint matching issues
        print("🔍 SquatAnalyzer: Checking for required keypoints: \(required)")
        print("🔍 SquatAnalyzer: Found keypoints (lowercased): \(foundKeypoints)")
        
        // Check for missing keypoints using case-insensitive matching
        let missing = required.filter { requiredName in
            !foundKeypoints.contains(requiredName.lowercased())
        }
        
        if !missing.isEmpty {
            print("⚠️ SquatAnalyzer: Missing keypoints: \(missing)")
        }
        
        return missing
    }
    
    /// Calculate average confidence across all keypoints in valid poses
    private static func calculateAverageConfidence(_ poses: [PoseDetectionResult]) -> Float {
        guard !poses.isEmpty else { return 0 }
        
        var totalConfidence: Float = 0
        var count: Int = 0
        
        for pose in poses {
            for keypoint in pose.keypoints {
                totalConfidence += keypoint.confidence
                count += 1
            }
        }
        
        return count > 0 ? totalConfidence / Float(count) : 0
    }
}

// MARK: - Squat Analysis Error

enum SquatAnalysisError: DetailedError {
    case noPoseData
    case insufficientValidFrames(count: Int, required: Int)
    case missingRequiredKeypoints(missing: [String])
    case lowPoseConfidence(averageConfidence: Double, threshold: Double)
    case noMovementPhasesDetected
    case invalidPoseSequence(reason: String)
    
    var primaryMessage: String {
        switch self {
        case .noPoseData:
            return "No pose detection data available"
        case .insufficientValidFrames(let count, let required):
            return "Not enough valid frames detected (\(count) of \(required) required)"
        case .missingRequiredKeypoints(let missing):
            let joints = missing.joined(separator: ", ")
            return "Required body joints not detected: \(joints)"
        case .lowPoseConfidence(let avg, let threshold):
            return "Pose detection confidence too low (average: \(String(format: "%.1f", avg * 100))%, need: \(String(format: "%.1f", threshold * 100))%)"
        case .noMovementPhasesDetected:
            return "No movement phases detected in the recording"
        case .invalidPoseSequence(let reason):
            return "Invalid pose sequence: \(reason)"
        }
    }
    
    var diagnosticInfo: String? {
        switch self {
        case .insufficientValidFrames(let count, let required):
            return "Detected \(count) valid frames, but need at least \(required) frames for analysis"
        case .missingRequiredKeypoints(let missing):
            return "Missing keypoints: \(missing.joined(separator: ", "))"
        case .lowPoseConfidence(let avg, let threshold):
            return "Average confidence: \(String(format: "%.2f", avg)), threshold: \(String(format: "%.2f", threshold))"
        case .invalidPoseSequence(let reason):
            return reason
        default:
            return nil
        }
    }
    
    var userTips: [String] {
        switch self {
        case .noPoseData:
            return VideoCaptureTips.tipsForNoPoseData
        case .insufficientValidFrames:
            return VideoCaptureTips.tipsForInsufficientFrames
        case .missingRequiredKeypoints:
            return VideoCaptureTips.tipsForMissingKeypoints
        case .lowPoseConfidence:
            return VideoCaptureTips.tipsForLowConfidence
        case .noMovementPhasesDetected:
            return VideoCaptureTips.tipsForNoMovement
        case .invalidPoseSequence:
            return VideoCaptureTips.generalTips
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .insufficientValidFrames:
            return "Try recording for at least 3-5 seconds with continuous movement"
        case .missingRequiredKeypoints:
            return "Reposition yourself so your full body is visible in the frame"
        case .lowPoseConfidence:
            return "Improve lighting and ensure clear background contrast"
        case .noMovementPhasesDetected:
            return "Ensure you perform the complete movement from start to finish"
        default:
            return "Try recording again with better positioning and lighting"
        }
    }
}

// MARK: - Analysis Result Models

struct SquatAnalysisResult: Codable {
    let phases: [SquatPhase]
    let reps: [SquatRep]
    let depthMetrics: [DepthAnalysis]
    let kneeMetrics: [KneeAnalysis]
    let worstDepth: DepthAnalysis?
    let worstKneeAngle: KneeAnalysis?
    let overallScore: Double
    let feedback: [FormFeedback]
}

struct SquatRep: Codable, Identifiable {
    let id: UUID
    let repNumber: Int  // 1-indexed
    let startFrame: Int
    let endFrame: Int
    let startTime: TimeInterval
    let endTime: TimeInterval
    let isFullRep: Bool
    let bottomFrame: Int
    let bottomTime: TimeInterval
    let reachedDepth: Bool  // Did this rep reach proper depth?
    let returnedToStart: Bool  // Did this rep return to starting height?
    
    init(repNumber: Int, startFrame: Int, endFrame: Int, startTime: TimeInterval, endTime: TimeInterval, isFullRep: Bool, bottomFrame: Int, bottomTime: TimeInterval, reachedDepth: Bool, returnedToStart: Bool) {
        self.id = UUID()
        self.repNumber = repNumber
        self.startFrame = startFrame
        self.endFrame = endFrame
        self.startTime = startTime
        self.endTime = endTime
        self.isFullRep = isFullRep
        self.bottomFrame = bottomFrame
        self.bottomTime = bottomTime
        self.reachedDepth = reachedDepth
        self.returnedToStart = returnedToStart
    }
}

enum SquatPhaseType: String, Codable {
    case setup = "setup"
    case descent = "descent"
    case bottom = "bottom"
    case ascent = "ascent"
}

struct SquatPhase: Codable, Identifiable {
    let id: UUID
    let type: SquatPhaseType
    let startFrame: Int
    let endFrame: Int
    let startTime: TimeInterval
    let endTime: TimeInterval
    
    init(type: SquatPhaseType, startFrame: Int, endFrame: Int, startTime: TimeInterval, endTime: TimeInterval) {
        self.id = UUID()
        self.type = type
        self.startFrame = startFrame
        self.endFrame = endFrame
        self.startTime = startTime
        self.endTime = endTime
    }
}

struct DepthAnalysis: Codable {
    let hipHeight: Double
    let kneeHeight: Double
    let isAtDepth: Bool
    let depthPercentage: Double
    let timestamp: Date
    let repNumber: Int?  // Which rep this metric belongs to
}

struct KneeAnalysis: Codable {
    let leftAngle: Double
    let rightAngle: Double
    let minAngle: Double
    let maxAngle: Double
    let averageAngle: Double
    let kneeValgus: Double
    let hasValgus: Bool
    let timestamp: Date
    let repNumber: Int?  // Which rep this metric belongs to
}

enum BackRoundingSeverity: String, Codable {
    case none = "none"
    case mild = "mild"
    case moderate = "moderate"
    case severe = "severe"
}

