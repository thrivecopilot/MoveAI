//
//  ProfileUnits.swift
//  MoveAI
//
//  Canonical units for the stored user profile and the only place that
//  formats them for display.
//
//  Storage convention: @AppStorage("userHeight") is centimeters and
//  @AppStorage("userWeight") is kilograms — matching what
//  PersonalInfoStepView writes and what HealthKit imports provide.
//  Views must not do their own unit math; route everything through here.
//

import Foundation

enum ProfileUnits {

    static let centimetersPerInch = 2.54
    static let poundsPerKilogram = 2.20462

    /// "5'10\"" (optionally with a metric suffix); zero → "Not set".
    static func formatHeight(cm: Double, includeMetric: Bool = false) -> String {
        guard cm > 0 else { return "Not set" }
        let totalInches = Int((cm / centimetersPerInch).rounded())
        let feet = totalInches / 12
        let inches = totalInches % 12
        let imperial = "\(feet)'\(inches)\""
        return includeMetric ? "\(imperial) (\(Int(cm.rounded())) cm)" : imperial
    }

    /// "180 lbs" (optionally with a metric suffix); zero → "Not set".
    static func formatWeight(kg: Double, includeMetric: Bool = false) -> String {
        guard kg > 0 else { return "Not set" }
        let pounds = Int((kg * poundsPerKilogram).rounded())
        return includeMetric ? "\(pounds) lbs (\(Int(kg.rounded())) kg)" : "\(pounds) lbs"
    }
}
