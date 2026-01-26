//
//  VideoTestParser.swift
//  MoveAITests
//
//  Created by Dave Mathew on 10/11/25.
//

import Foundation

/// Parser for CSV-format expected test results
class VideoTestParser {
    
    /// Parse expected results from CSV content
    /// CSV format: rep_number,start_frame,bottom_frame,end_frame,depth_quality,full_vs_partial,knee_valgus,back_rounding
    static func parseExpectedResults(from csv: String) throws -> ExpectedResults {
        let lines = csv.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        guard !lines.isEmpty else {
            throw ParsingError.emptyFile
        }
        
        // Parse header row
        let headerLine = lines[0]
        let headers = parseCSVRow(headerLine)
        
        // Expected columns: rep_number,start_frame,bottom_frame,end_frame,depth_quality,full_vs_partial,knee_valgus,back_rounding
        guard let repNumIndex = headers.firstIndex(of: "rep_number"),
              let startFrameIndex = headers.firstIndex(of: "start_frame"),
              let bottomFrameIndex = headers.firstIndex(of: "bottom_frame"),
              let endFrameIndex = headers.firstIndex(of: "end_frame"),
              let depthQualityIndex = headers.firstIndex(of: "depth_quality"),
              let fullVsPartialIndex = headers.firstIndex(of: "full_vs_partial"),
              let kneeValgusIndex = headers.firstIndex(of: "knee_valgus"),
              let backRoundingIndex = headers.firstIndex(of: "back_rounding") else {
            throw ParsingError.invalidFormat
        }
        
        var repFrameRanges: [ExpectedResults.RepFrameRange] = []
        var depthQuality: [Int: ExpectedResults.DepthQuality] = [:]
        var fullReps: [Int: Bool] = [:]
        var kneeValgus: [Int: Bool] = [:]
        var backRounding: [Int: ExpectedResults.BackRoundingSeverity] = [:]
        
        // Parse data rows
        for i in 1..<lines.count {
            let row = parseCSVRow(lines[i])
            
            guard row.count > max(repNumIndex, startFrameIndex, bottomFrameIndex, endFrameIndex, depthQualityIndex, fullVsPartialIndex, kneeValgusIndex, backRoundingIndex) else {
                continue // Skip incomplete rows
            }
            
            // Parse rep number
            guard let repNum = Int(row[repNumIndex]) else {
                continue
            }
            
            // Parse frame ranges
            if let startFrame = Int(row[startFrameIndex]),
               let bottomFrame = Int(row[bottomFrameIndex]),
               let endFrame = Int(row[endFrameIndex]) {
                let tolerance = 20 // Default tolerance: ±20 frames
                repFrameRanges.append(ExpectedResults.RepFrameRange(
                    repNumber: repNum,
                    startFrame: startFrame,
                    bottomFrame: bottomFrame,
                    endFrame: endFrame,
                    tolerance: tolerance
                ))
            }
            
            // Parse depth quality
            let depthQualityStr = row[depthQualityIndex].uppercased()
            if depthQualityStr.contains("EXCELLENT") {
                depthQuality[repNum] = .excellent
            } else if depthQualityStr.contains("SHALLOW") {
                // Extract depth percentage if present (e.g., "SHALLOW 60%" or "SHALLOW (60%)")
                var depthPercentage: Double? = nil
                let numbers = row[depthQualityIndex].components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                if let percent = Double(numbers), percent > 0 {
                    depthPercentage = percent
                }
                depthQuality[repNum] = .shallow(depthPercentage: depthPercentage)
            }
            
            // Parse full vs partial
            let fullVsPartialStr = row[fullVsPartialIndex].uppercased()
            fullReps[repNum] = fullVsPartialStr.contains("FULL")
            
            // Parse knee valgus
            let kneeValgusStr = row[kneeValgusIndex].uppercased()
            kneeValgus[repNum] = kneeValgusStr.contains("DETECTED") || kneeValgusStr.contains("YES")
            
            // Parse back rounding
            let backRoundingStr = row[backRoundingIndex].uppercased()
            if backRoundingStr.contains("SEVERE") {
                backRounding[repNum] = .severe
            } else if backRoundingStr.contains("MODERATE") {
                backRounding[repNum] = .moderate
            } else if backRoundingStr.contains("MILD") {
                backRounding[repNum] = .mild
            } else {
                backRounding[repNum] = .none
            }
        }
        
        let repCount = repFrameRanges.count
        
        guard repCount > 0 else {
            throw ParsingError.missingRepCount
        }
        
        return ExpectedResults(
            repCount: repCount,
            repFrameRanges: repFrameRanges.sorted(by: { $0.repNumber < $1.repNumber }),
            depthQuality: depthQuality,
            fullReps: fullReps,
            kneeValgus: kneeValgus,
            backRounding: backRounding
        )
    }
    
    // MARK: - CSV Parsing Helper
    
    /// Parse a CSV row, handling quoted fields
    private static func parseCSVRow(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var inQuotes = false
        
        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                fields.append(currentField.trimmingCharacters(in: .whitespaces))
                currentField = ""
            } else {
                currentField.append(char)
            }
        }
        
        // Add last field
        fields.append(currentField.trimmingCharacters(in: .whitespaces))
        
        return fields
    }
    
    enum ParsingError: Error {
        case emptyFile
        case missingRepCount
        case invalidFormat
    }
}
