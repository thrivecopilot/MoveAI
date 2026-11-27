//
//  ProfileUnitsTests.swift
//  MoveAITests
//
//  Stored profile units are metric (cm/kg); display is imperial. These guard
//  the conversions that previously diverged per-view (the "14'9\"" bug).
//

import XCTest
@testable import MoveAI

final class ProfileUnitsTests: XCTestCase {

    // MARK: - Height

    func testHeightFormatsMetricStorageAsImperial() {
        // 177.8 cm is exactly 70 inches — the value UI tests seed.
        XCTAssertEqual(ProfileUnits.formatHeight(cm: 177.8), "5'10\"")
    }

    func testHeightRoundsInsteadOfTruncating() {
        // 69.99" must not truncate down to 5'9".
        XCTAssertEqual(ProfileUnits.formatHeight(cm: 177.79), "5'10\"")
    }

    func testHeightInchRolloverProducesWholeFeet() {
        // 182.6 cm ≈ 71.9" → must round to 6'0", never "5'12\"".
        XCTAssertEqual(ProfileUnits.formatHeight(cm: 182.6), "6'0\"")
    }

    func testHeightZeroIsNotSet() {
        XCTAssertEqual(ProfileUnits.formatHeight(cm: 0), "Not set")
    }

    func testHeightMetricSuffix() {
        XCTAssertEqual(ProfileUnits.formatHeight(cm: 177.8, includeMetric: true), "5'10\" (178 cm)")
    }

    // MARK: - Weight

    func testWeightFormatsMetricStorageAsImperial() {
        // 81.64656 kg is exactly 180 lbs — the value UI tests seed.
        XCTAssertEqual(ProfileUnits.formatWeight(kg: 81.64656), "180 lbs")
    }

    func testWeightZeroIsNotSet() {
        XCTAssertEqual(ProfileUnits.formatWeight(kg: 0), "Not set")
    }

    func testWeightMetricSuffix() {
        XCTAssertEqual(ProfileUnits.formatWeight(kg: 81.64656, includeMetric: true), "180 lbs (82 kg)")
    }

    // MARK: - Round-trip stability (PersonalInfoStepView edit cycle)

    func testHeightSurvivesRepeatedEditCycles() {
        // Simulate open-editor → save repeatedly; height must not drift.
        var storedCm = 177.8
        for _ in 0..<10 {
            let totalInches = Int((storedCm / ProfileUnits.centimetersPerInch).rounded())
            storedCm = Double(totalInches) * ProfileUnits.centimetersPerInch
        }
        XCTAssertEqual(ProfileUnits.formatHeight(cm: storedCm), "5'10\"")
    }

    func testWeightSurvivesRepeatedEditCycles() {
        var storedKg = 81.64656
        for _ in 0..<10 {
            let pounds = (storedKg * ProfileUnits.poundsPerKilogram).rounded()
            storedKg = pounds / ProfileUnits.poundsPerKilogram
        }
        XCTAssertEqual(ProfileUnits.formatWeight(kg: storedKg), "180 lbs")
    }

    // MARK: - HealthKit import path (HealthProfile → stored metric)

    func testHealthProfileImportStoresMetric() {
        let profile = HealthProfile(heightFeet: 5, heightInches: 10, weightLbs: 180, age: 31)
        XCTAssertEqual(ProfileUnits.formatHeight(cm: profile.heightInCm), "5'10\"")
        XCTAssertEqual(ProfileUnits.formatWeight(kg: profile.weightInKg), "180 lbs")
    }
}
