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
        // Minimum required: hips and knees (for depth analysis)
        // Ankles and shoulders are optional (for knee angle and back angle analyses)
        let requiredKeypoints = ["leftHip", "rightHip", "leftKnee", "rightKnee"]
        
        // Analyze keypoint availability
        let missingKeypoints = findMissingKeypoints(in: poseHistory, required: requiredKeypoints)
        if !missingKeypoints.isEmpty {
            return .failure(.missingRequiredKeypoints(missing: missingKeypoints))
        }
        
        // Filter out frames with insufficient keypoints
        let validPoses = poseHistory.filter { pose in
            PoseAnalysisHelpers.hasRequiredKeypoints(
                pose,
                required: requiredKeypoints,
                minConfidence: 0.3
            )
        }
        
        print("🔍 SquatAnalyzer: Total pose history: \(poseHistory.count) frames, Valid poses after filtering: \(validPoses.count) frames")
        
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
        let hipHeights = validPoses.compactMap { pose -> Double? in
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
        
        guard hipHeights.count == validPoses.count else {
            return .failure(.invalidPoseSequence(reason: "Unable to extract hip heights"))
        }
        
        // Smooth the data to reduce noise
        let smoothedHeights = PoseAnalysisHelpers.smoothValues(hipHeights, windowSize: 5)
        
        // Get reference heights for depth calculation
        let startingHipHeight = getStartingHipHeight(validPoses)
        let minimumHipHeight = getMinimumHipHeight(validPoses)
        
        // Detect reps (descent/ascent cycles)
        let minDepthThreshold = 0.05  // Minimum 5% change in normalized height to count as a rep
        let reps = detectReps(validPoses, smoothedHeights: smoothedHeights, startHeight: startingHipHeight, minDepthThreshold: minDepthThreshold)
        
        // Detect phases (for backward compatibility, but now we have reps)
        let phases = detectPhases(validPoses)
        
        // Check if phases were detected
        guard !phases.isEmpty else {
            return .failure(.noMovementPhasesDetected)
        }
        
        // Helper function to determine which rep a frame belongs to
        func repNumberForFrame(_ frameIndex: Int) -> Int? {
            return reps.first(where: { frameIndex >= $0.startFrame && frameIndex <= $0.endFrame })?.repNumber
        }
        
        // Calculate metrics for each phase, associating with rep numbers
        var depthMetrics: [DepthAnalysis] = []
        var kneeMetrics: [KneeAnalysis] = []
        var backMetrics: [BackAnalysis] = []
        
        for (index, pose) in validPoses.enumerated() {
            let repNum = repNumberForFrame(index)
            
            if let depth = calculateDepth(pose, startHeight: startingHipHeight, minHeight: minimumHipHeight, repNumber: repNum) {
                depthMetrics.append(depth)
            }
            if let knee = calculateKneeAngles(pose, repNumber: repNum) {
                kneeMetrics.append(knee)
            }
            if let back = calculateBackAngle(pose, repNumber: repNum) {
                backMetrics.append(back)
            }
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
        let backMetricsWithReps = backMetrics.filter { $0.repNumber != nil }
        
        // Find worst-case scenarios from metrics that have rep numbers
        // If no metrics with rep numbers exist, fall back to all metrics and assign rep numbers
        let worstDepthCandidate = (depthMetricsWithReps.isEmpty ? depthMetrics : depthMetricsWithReps).min { $0.depthPercentage < $1.depthPercentage }
        let worstKneeAngleCandidate = (kneeMetricsWithReps.isEmpty ? kneeMetrics : kneeMetricsWithReps).min { $0.minAngle < $1.minAngle }
        let worstBackAngleCandidate = (backMetricsWithReps.isEmpty ? backMetrics : backMetricsWithReps).max { $0.spineAngle > $1.spineAngle }
        
        // Ensure all worst metrics have rep numbers (assign to nearest rep if missing)
        let worstDepth = worstDepthCandidate.flatMap { depth in
            depth.repNumber != nil ? depth : assignRepNumberToDepthMetric(depth, reps: reps)
        }
        let worstKneeAngle = worstKneeAngleCandidate.flatMap { knee in
            knee.repNumber != nil ? knee : assignRepNumberToKneeMetric(knee, reps: reps)
        }
        let worstBackAngle = worstBackAngleCandidate.flatMap { back in
            back.repNumber != nil ? back : assignRepNumberToBackMetric(back, reps: reps)
        }
        
        // Calculate overall score
        let score = calculateOverallScore(
            depth: worstDepth,
            knee: worstKneeAngle,
            back: worstBackAngle
        )
        
        // Generate feedback (using relative timestamps from start of recording)
        let startTime = validPoses.first?.timestamp ?? Date()
        let feedback = generateFeedback(
            phases: phases,
            reps: reps,
            depthMetrics: depthMetrics,
            kneeMetrics: kneeMetrics,
            backMetrics: backMetrics,
            worstDepth: worstDepth,
            worstKnee: worstKneeAngle,
            worstBack: worstBackAngle,
            startTime: startTime
        )
        
        let result = SquatAnalysisResult(
            phases: phases,
            reps: reps,
            depthMetrics: depthMetrics,
            kneeMetrics: kneeMetrics,
            backMetrics: backMetrics,
            worstDepth: worstDepth,
            worstKneeAngle: worstKneeAngle,
            worstBackAngle: worstBackAngle,
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
        startHeight: Double,
        minDepthThreshold: Double
    ) -> [SquatRep] {
        guard poses.count >= 3, smoothedHeights.count == poses.count else { return [] }
        
        var reps: [SquatRep] = []
        
        // Note: In normalized coordinates, Y increases downward
        // When hip is at bottom (lowest), Y is maximum
        // When hip is at top (highest), Y is minimum
        var bottoms: [Int] = []  // Frame indices of bottom positions (local maxima in Y)
        var tops: [Int] = []     // Frame indices of top positions (local minima in Y)
        
        // Window size for detecting local extrema (avoid noise)
        let windowSize = 5
        
        // Find local maxima (bottom positions - hip is lowest, Y is maximum)
        for i in windowSize..<(smoothedHeights.count - windowSize) {
            let current = smoothedHeights[i]
            let isLocalMax = (1...windowSize).allSatisfy { offset in
                smoothedHeights[i - offset] <= current && smoothedHeights[i + offset] <= current
            }
            if isLocalMax {
                bottoms.append(i)
            }
        }
        
        // Find local minima (top positions - hip is highest, Y is minimum)
        for i in windowSize..<(smoothedHeights.count - windowSize) {
            let current = smoothedHeights[i]
            let isLocalMin = (1...windowSize).allSatisfy { offset in
                smoothedHeights[i - offset] >= current && smoothedHeights[i + offset] >= current
            }
            if isLocalMin {
                tops.append(i)
            }
        }
        
        // Filter out extrema that don't have significant change
        let minDepthChange = 0.05  // Minimum 5% change in normalized height
        tops = tops.filter { index in
            guard index > 0 && index < smoothedHeights.count - 1 else { return false }
            // Check if there's a significant descent/ascent around this top
            let hasSignificantChange = bottoms.contains { bottom in
                abs(smoothedHeights[bottom] - smoothedHeights[index]) > minDepthChange
            }
            return hasSignificantChange
        }
        
        bottoms = bottoms.filter { index in
            guard index > 0 && index < smoothedHeights.count - 1 else { return false }
            // Check if there's a significant change from nearby tops
            let hasSignificantChange = tops.contains { top in
                abs(smoothedHeights[index] - smoothedHeights[top]) > minDepthChange
            }
            return hasSignificantChange
        }
        
        // Debug: Log detected extrema
        print("🔍 detectReps: Found \(tops.count) tops at indices: \(tops)")
        print("🔍 detectReps: Found \(bottoms.count) bottoms at indices: \(bottoms)")
        
        // Group into cycles: start at a top → descend to bottom → ascend to next top
        // We need at least one top to start from, or start from beginning
        var repNumber = 1
        var cycleStart = 0
        
        // If we have tops, start from the first one (or just before it)
        if let firstTop = tops.first, firstTop > 0 {
            cycleStart = max(0, firstTop - 1)
        }
        
        var currentTopIndex = 0
        
        while currentTopIndex < tops.count {
            let startTop = tops[currentTopIndex]
            
            // Find the next bottom after this top
            guard let nextBottom = bottoms.first(where: { $0 > startTop }) else {
                // No bottom found after this top - might be end of recording
                // Check if we have a significant descent that could be a partial rep
                if startTop < poses.count - 10 {
                    // Look for any significant movement after this top
                    let endFrame = poses.count - 1
                    let endHeight = smoothedHeights[endFrame]
                    let heightChange = abs(endHeight - smoothedHeights[startTop])
                    
                    if heightChange > minDepthThreshold {
                        // Partial rep - descended but didn't complete
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
            
            // Find the next top after this bottom (completing the cycle)
            let nextTop = tops.first(where: { $0 > nextBottom }) ?? poses.count - 1
            
            // Check if this rep reached proper depth
            // Depth is achieved when hip goes significantly below starting height
            let bottomHeight = smoothedHeights[nextBottom]
            let depthChange = bottomHeight - smoothedHeights[startTop]
            let reachedDepth = depthChange > minDepthThreshold
            
            // Check if returned to starting height (within threshold)
            let endHeight = nextTop < smoothedHeights.count ? smoothedHeights[nextTop] : (smoothedHeights.last ?? startHeight)
            let startTopHeight = smoothedHeights[startTop]
            let heightDifference = abs(endHeight - startTopHeight)
            let returnedToStart = heightDifference < 0.03  // Within 3% of starting top height
            
            let isFullRep = reachedDepth && returnedToStart
            
            // Only create rep if it has minimum duration (at least 10 frames) and significant movement
            let cycleDuration = nextTop - cycleStart
            let hasSignificantMovement = depthChange > minDepthThreshold * 0.5  // At least half the threshold
            
            if cycleDuration >= 10 && hasSignificantMovement {
                reps.append(SquatRep(
                    repNumber: repNumber,
                    startFrame: cycleStart,
                    endFrame: min(nextTop, poses.count - 1),
                    startTime: poses[cycleStart].timestamp.timeIntervalSince1970,
                    endTime: poses[min(nextTop, poses.count - 1)].timestamp.timeIntervalSince1970,
                    isFullRep: isFullRep,
                    bottomFrame: nextBottom,
                    bottomTime: poses[nextBottom].timestamp.timeIntervalSince1970,
                    reachedDepth: reachedDepth,
                    returnedToStart: returnedToStart
                ))
                
                print("🔍 detectReps: Created rep \(repNumber): frames \(cycleStart)-\(min(nextTop, poses.count - 1)), bottom at \(nextBottom), depthChange=\(String(format: "%.3f", depthChange))")
                
                repNumber += 1
            }
            
            // Move to next cycle - start from the next top
            cycleStart = nextTop
            
            // Find the index of nextTop in the tops array, then move to the next one
            if let currentTopIndexInArray = tops.firstIndex(of: nextTop) {
                // Move to the next top in the array
                let nextTopIndexInArray = currentTopIndexInArray + 1
                if nextTopIndexInArray < tops.count {
                    currentTopIndex = nextTopIndexInArray
                    // Debug: Log continuation
                    print("🔍 detectReps: Moving to next top at index \(tops[currentTopIndex]) for rep \(repNumber)")
                } else {
                    // No more tops in array, but check if there's a final rep after this top
                    // This handles the case where the last rep ends at the end of the sequence
                    print("🔍 detectReps: At last top (\(nextTop)), checking for final rep")
                    
                    // Check if there's significant movement after this top that could form another rep
                    // Always check, regardless of remaining frame count - let the rep creation logic handle duration requirements
                    let endFrame = poses.count - 1
                    let remainingFrames = endFrame - nextTop
                    print("🔍 detectReps: endFrame=\(endFrame), nextTop=\(nextTop), remaining frames=\(remainingFrames)")
                    
                    // Find the deepest point (bottom) after this top
                    let remainingFrameRange = nextTop..<smoothedHeights.count
                    if let bottomIndex = remainingFrameRange.max(by: { smoothedHeights[$0] < smoothedHeights[$1] }) {
                        let bottomHeight = smoothedHeights[bottomIndex]
                        let startTopHeight = smoothedHeights[nextTop]
                        let depthChange = bottomHeight - startTopHeight
                        let reachedDepth = depthChange > minDepthThreshold
                        
                        print("🔍 detectReps: Found bottom at \(bottomIndex), depthChange=\(String(format: "%.3f", depthChange)), threshold=\(String(format: "%.3f", minDepthThreshold))")
                        
                        // Check if returned to starting height
                        let endHeight = smoothedHeights[endFrame]
                        let heightDifference = abs(endHeight - startTopHeight)
                        let returnedToStart = heightDifference < 0.03
                        let isFullRep = reachedDepth && returnedToStart
                        
                        let cycleDuration = endFrame - nextTop
                        let hasSignificantMovement = depthChange > minDepthThreshold * 0.5
                        
                        print("🔍 detectReps: cycleDuration=\(cycleDuration), hasSignificantMovement=\(hasSignificantMovement), reachedDepth=\(reachedDepth)")
                        
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
                        print("🔍 detectReps: Found next top at index \(nextTopAfterBottom) for rep \(repNumber)")
                    } else {
                        break
                    }
                } else {
                    // No more tops found
                    print("🔍 detectReps: No more tops after bottom at \(nextBottom), detected \(repNumber) reps")
                    break
                }
            }
        }
        
        // If no reps were detected but we have significant movement, create a single rep
        if reps.isEmpty && poses.count >= 10 {
            let totalHeightChange = abs(smoothedHeights.last! - smoothedHeights.first!)
            if totalHeightChange > minDepthThreshold {
                // Single rep covering entire sequence
                let endFrame = poses.count - 1
                let bottomIndex = smoothedHeights.enumerated().max(by: { $0.element < $1.element })?.offset ?? endFrame
                let bottomHeight = smoothedHeights[bottomIndex]
                let reachedDepth = (bottomHeight - startHeight) > minDepthThreshold
                let returnedToStart = abs(smoothedHeights[endFrame] - startHeight) < 0.03
                
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
        
        // Debug: Log final result
        print("🔍 detectReps: Final result - detected \(reps.count) reps")
        for rep in reps {
            print("  - Rep \(rep.repNumber): frames \(rep.startFrame)-\(rep.endFrame), isFullRep=\(rep.isFullRep)")
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
        
        // Find bottom position (maximum Y value = lowest point)
        guard let bottomIndex = smoothedHeights.enumerated().max(by: { $0.element < $1.element })?.offset else {
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
    static func calculateDepth(_ pose: PoseDetectionResult, startHeight: Double, minHeight: Double, repNumber: Int? = nil) -> DepthAnalysis? {
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
        
        guard let hipPos = PoseAnalysisHelpers.averagePosition(leftHip, rightHip),
              let kneePos = PoseAnalysisHelpers.averagePosition(leftKnee, rightKnee) else {
            return nil
        }
        
        let hipY = Double(hipPos.y)
        let kneeY = Double(kneePos.y)
        
        // Depth is achieved when hip crease is below knee level
        let isAtDepth = hipY > kneeY
        
        // Calculate depth percentage (0 = standing, 100 = maximum depth achieved)
        let depthPercentage = PoseAnalysisHelpers.calculateDepthPercentage(
            currentY: hipY,
            startY: startHeight,
            bottomY: minHeight
        )
        
        return DepthAnalysis(
            hipHeight: hipY,
            kneeHeight: kneeY,
            isAtDepth: isAtDepth,
            depthPercentage: depthPercentage,
            timestamp: pose.timestamp,
            repNumber: repNumber
        )
    }
    
    // MARK: - Knee Angle Analysis
    
    /// Calculate knee angle metrics for a single pose
    static func calculateKneeAngles(_ pose: PoseDetectionResult, repNumber: Int? = nil) -> KneeAnalysis? {
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
        
        // Calculate knee valgus (knees caving inward)
        let kneeValgus: Double
        if let leftKnee = leftKnee, let rightKnee = rightKnee {
            kneeValgus = abs(Double(leftKnee.position.x - rightKnee.position.x))
        } else {
            kneeValgus = 0
        }
        
        // Check for excessive valgus (knees too close together relative to ankles)
        let hasValgus = kneeValgus > 0.05 // Threshold in normalized coordinates
        
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
    
    // MARK: - Back Angle Analysis
    
    /// Calculate back angle and rounding for a single pose
    static func calculateBackAngle(_ pose: PoseDetectionResult, repNumber: Int? = nil) -> BackAnalysis? {
        let (leftShoulder, rightShoulder) = PoseAnalysisHelpers.extractBilateralKeypoints(
            leftName: "leftShoulder",
            rightName: "rightShoulder",
            from: pose
        )
        let (leftHip, rightHip) = PoseAnalysisHelpers.extractBilateralKeypoints(
            leftName: "leftHip",
            rightName: "rightHip",
            from: pose
        )
        
        guard let shoulderPos = PoseAnalysisHelpers.averagePosition(leftShoulder, rightShoulder),
              let hipPos = PoseAnalysisHelpers.averagePosition(leftHip, rightHip) else {
            return nil
        }
        
        // Calculate spine angle (angle of shoulder-hip line relative to vertical)
        let spineAngle = PoseAnalysisHelpers.calculateVerticalAngle(
            from: shoulderPos,
            to: hipPos
        )
        
        // Detect back rounding
        // Back is rounded if spine angle deviates significantly from ideal (0-15 degrees)
        let isRounded = spineAngle > 20 // Threshold for back rounding
        
        // Calculate rounding severity
        let roundingSeverity: BackRoundingSeverity
        if spineAngle > 35 {
            roundingSeverity = .severe
        } else if spineAngle > 25 {
            roundingSeverity = .moderate
        } else if spineAngle > 20 {
            roundingSeverity = .mild
        } else {
            roundingSeverity = .none
        }
        
        return BackAnalysis(
            spineAngle: spineAngle,
            isRounded: isRounded,
            roundingSeverity: roundingSeverity,
            timestamp: pose.timestamp,
            repNumber: repNumber
        )
    }
    
    // MARK: - Score Calculation
    
    /// Calculate overall form score (0-100)
    static func calculateOverallScore(
        depth: DepthAnalysis?,
        knee: KneeAnalysis?,
        back: BackAnalysis?
    ) -> Double {
        var score = 100.0
        
        // Depth scoring (30% weight)
        if let depth = depth {
            if depth.isAtDepth {
                // Full points for proper depth
            } else if depth.depthPercentage > 80 {
                score -= 5 // Slightly shallow
            } else if depth.depthPercentage > 60 {
                score -= 15 // Moderately shallow
            } else {
                score -= 30 // Very shallow
            }
        } else {
            score -= 10 // Missing depth data
        }
        
        // Knee angle scoring (30% weight)
        // Optional analysis - don't penalize if missing (ankles may not be detected)
        if let knee = knee {
            if knee.hasValgus {
                score -= 20 // Knee valgus is dangerous
            }
            if knee.minAngle < 60 {
                score -= 10 // Very deep, but check if controlled
            }
        }
        // No penalty for missing knee data - it's an optional analysis
        
        // Back rounding scoring (40% weight - most important for safety)
        // Optional analysis - don't penalize if missing (shoulders may not be detected)
        if let back = back {
            switch back.roundingSeverity {
            case .severe:
                score -= 40 // Dangerous
            case .moderate:
                score -= 25 // Risky
            case .mild:
                score -= 10 // Needs attention
            case .none:
                break // Good
            }
        }
        // No penalty for missing back data - it's an optional analysis
        
        return max(0, min(100, score))
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
    static func assignRepNumberToBackMetric(_ metric: BackAnalysis, reps: [SquatRep]) -> BackAnalysis? {
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
        
        return BackAnalysis(
            spineAngle: metric.spineAngle,
            isRounded: metric.isRounded,
            roundingSeverity: metric.roundingSeverity,
            timestamp: metric.timestamp,
            repNumber: rep.repNumber
        )
    }
    
    // MARK: - Feedback Generation
    
    /// Generate actionable feedback from analysis results
    static func generateFeedback(
        phases: [SquatPhase],
        reps: [SquatRep],
        depthMetrics: [DepthAnalysis],
        kneeMetrics: [KneeAnalysis],
        backMetrics: [BackAnalysis],
        worstDepth: DepthAnalysis?,
        worstKnee: KneeAnalysis?,
        worstBack: BackAnalysis?,
        startTime: Date
    ) -> [FormFeedback] {
        var feedback: [FormFeedback] = []
        
        // Helper function to format rep number as ordinal
        func formatRepNumber(_ repNumber: Int?) -> String {
            guard let rep = repNumber else { return "" }
            let suffix: String
            switch rep {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
            return "\(rep)\(suffix) rep"
        }
        
        // Helper function to format timestamp
        func formatTimestamp(_ timestamp: TimeInterval) -> String {
            return String(format: "%.1f seconds", timestamp)
        }
        
        // Depth feedback
        if let depth = worstDepth {
            let timestamp = depth.timestamp.timeIntervalSince(startTime)
            let repContext = depth.repNumber != nil ? " on \(formatRepNumber(depth.repNumber)) (\(formatTimestamp(timestamp)))" : " (\(formatTimestamp(timestamp)))"
            
            // Check if this rep is full
            let isFullRep = depth.repNumber.flatMap { repNum in
                reps.first(where: { $0.repNumber == repNum })?.isFullRep
            } ?? true // Default to true if rep number not found
            
            if !isFullRep {
                // Rep didn't complete full range of motion
                feedback.append(FormFeedback(
                    category: .rangeOfMotion,
                    message: "Incomplete range of motion - \(formatRepNumber(depth.repNumber)) did not return to starting position\(repContext)",
                    severity: .warning,
                    timestamp: timestamp,
                    repNumber: depth.repNumber
                ))
            } else if depth.isAtDepth {
                feedback.append(FormFeedback(
                    category: .rangeOfMotion,
                    message: "Excellent depth - hip crease below knee level\(repContext)",
                    severity: .excellent,
                    timestamp: timestamp,
                    repNumber: depth.repNumber
                ))
            } else if depth.depthPercentage > 80 {
                feedback.append(FormFeedback(
                    category: .rangeOfMotion,
                    message: "Good depth, but aim to get hip crease below knee level\(repContext)",
                    severity: .good,
                    timestamp: timestamp,
                    repNumber: depth.repNumber
                ))
            } else {
                feedback.append(FormFeedback(
                    category: .rangeOfMotion,
                    message: "Need to go deeper - hip crease should be below knee level\(repContext)",
                    severity: .warning,
                    timestamp: timestamp,
                    repNumber: depth.repNumber
                ))
            }
        }
        
        // Add feedback for all non-full reps (even if they weren't the worst depth)
        // This ensures all incomplete reps get feedback
        for rep in reps where !rep.isFullRep {
            // Check if we already added feedback for this rep
            let alreadyHasFeedback = feedback.contains { $0.repNumber == rep.repNumber && $0.category == .rangeOfMotion }
            
            if !alreadyHasFeedback {
                // rep.startTime is already a TimeInterval (seconds since 1970)
                // startTime is a Date, so we need to convert it to TimeInterval
                let startTimeInterval = startTime.timeIntervalSince1970
                let repTime = rep.startTime - startTimeInterval
                feedback.append(FormFeedback(
                    category: .rangeOfMotion,
                    message: "Incomplete range of motion - \(formatRepNumber(rep.repNumber)) did not complete full cycle (didn't return to starting position)",
                    severity: .warning,
                    timestamp: repTime,
                    repNumber: rep.repNumber
                ))
            }
        }
        
        // Knee feedback
        if let knee = worstKnee {
            let timestamp = knee.timestamp.timeIntervalSince(startTime)
            let repContext = knee.repNumber != nil ? " on \(formatRepNumber(knee.repNumber)) (\(formatTimestamp(timestamp)))" : " (\(formatTimestamp(timestamp)))"
            
            if knee.hasValgus {
                feedback.append(FormFeedback(
                    category: .safety,
                    message: "Knees caving inward detected - push knees out to align with toes\(repContext)",
                    severity: .critical,
                    timestamp: timestamp,
                    repNumber: knee.repNumber
                ))
            } else {
                feedback.append(FormFeedback(
                    category: .stability,
                    message: "Good knee tracking throughout the movement\(repContext)",
                    severity: .good,
                    timestamp: timestamp,
                    repNumber: knee.repNumber
                ))
            }
        }
        
        // Back feedback
        if let back = worstBack {
            let timestamp = back.timestamp.timeIntervalSince(startTime)
            let repContext = back.repNumber != nil ? " on \(formatRepNumber(back.repNumber)) (\(formatTimestamp(timestamp)))" : " (\(formatTimestamp(timestamp)))"
            
            switch back.roundingSeverity {
            case .severe:
                feedback.append(FormFeedback(
                    category: .safety,
                    message: "Significant back rounding detected - maintain neutral spine to prevent injury\(repContext)",
                    severity: .critical,
                    timestamp: timestamp,
                    repNumber: back.repNumber
                ))
            case .moderate:
                feedback.append(FormFeedback(
                    category: .posture,
                    message: "Moderate back rounding - focus on keeping chest up and core engaged\(repContext)",
                    severity: .warning,
                    timestamp: timestamp,
                    repNumber: back.repNumber
                ))
            case .mild:
                feedback.append(FormFeedback(
                    category: .posture,
                    message: "Slight back rounding - maintain neutral spine position\(repContext)",
                    severity: .warning,
                    timestamp: timestamp,
                    repNumber: back.repNumber
                ))
            case .none:
                feedback.append(FormFeedback(
                    category: .posture,
                    message: "Excellent back position - neutral spine maintained\(repContext)",
                    severity: .excellent,
                    timestamp: timestamp,
                    repNumber: back.repNumber
                ))
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
    let backMetrics: [BackAnalysis]
    let worstDepth: DepthAnalysis?
    let worstKneeAngle: KneeAnalysis?
    let worstBackAngle: BackAnalysis?
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

struct BackAnalysis: Codable {
    let spineAngle: Double
    let isRounded: Bool
    let roundingSeverity: BackRoundingSeverity
    let timestamp: Date
    let repNumber: Int?  // Which rep this metric belongs to
}

enum BackRoundingSeverity: String, Codable {
    case none = "none"
    case mild = "mild"
    case moderate = "moderate"
    case severe = "severe"
}

