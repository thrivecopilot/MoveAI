//
//  MuayThaiSelectionTests.swift
//  MoveAITests
//
//  Technique-picker behavior: selection memory, coverage badges, capture tips.
//

import XCTest
@testable import MoveAI

final class MuayThaiSelectionTests: XCTestCase {

    private var defaults: UserDefaults!

    override func setUp() {
        defaults = UserDefaults(suiteName: "MuayThaiSelectionTests")!
        defaults.removePersistentDomain(forName: "MuayThaiSelectionTests")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "MuayThaiSelectionTests")
    }

    // MARK: - Selection memory

    func testFirstLaunchDefaultsToAutoDetect() {
        let memory = MuayThaiSelectionMemory.load(from: defaults)
        XCTAssertTrue(memory.useAutoDetect, "Cold start must default to Auto Detect — a wrong manual technique gives confidently wrong coaching")
        XCTAssertEqual(memory.stance, .unknown, "Stance defaults to Auto Infer")
    }

    func testRememberedSelectionRoundTrips() {
        MuayThaiSelectionMemory(useAutoDetect: false, technique: .roundhouseKick, stance: .southpaw)
            .save(to: defaults)

        let restored = MuayThaiSelectionMemory.load(from: defaults)
        XCTAssertFalse(restored.useAutoDetect)
        XCTAssertEqual(restored.technique, .roundhouseKick)
        XCTAssertEqual(restored.stance, .southpaw)
    }

    func testCorruptStoredValuesFallBackToDefaults() {
        defaults.set("not_a_technique", forKey: MuayThaiSelectionMemory.techniqueKey)
        defaults.set("not_a_stance", forKey: MuayThaiSelectionMemory.stanceKey)

        let memory = MuayThaiSelectionMemory.load(from: defaults)
        XCTAssertEqual(memory.technique, .jab)
        XCTAssertEqual(memory.stance, .unknown)
    }

    // MARK: - Coverage badges

    func testEveryTechniqueHasCatalogCoverage() {
        for technique in MuayThaiTechnique.allCases {
            XCTAssertFalse(
                MuayThaiIssueCatalog.entries(for: technique).isEmpty,
                "\(technique.rawValue) has no catalog entries; coverage badge would be meaningless"
            )
        }
    }

    func testJabCoverageIsFullySupported() {
        XCTAssertEqual(MuayThaiIssueCatalog.coverage(for: .jab), .supported)
    }

    func testFixtureValidatedTechniquesShowFullAnalysis() {
        // Mirrors muay_thai_labeled_fixtures.json coverage.
        XCTAssertEqual(MuayThaiTechnique.jab.analysisDepth, .validated)
        XCTAssertEqual(MuayThaiTechnique.cross.analysisDepth, .validated)
        XCTAssertEqual(MuayThaiTechnique.roundhouseKick.analysisDepth, .validated)
        XCTAssertEqual(MuayThaiTechnique.teep.analysisDepth, .early)
        XCTAssertEqual(MuayThaiTechnique.movement.analysisDepth, .early)
    }

    // MARK: - Capture tips

    func testEveryTechniqueHasACaptureTip() {
        for technique in MuayThaiTechnique.allCases {
            XCTAssertFalse(technique.captureTip.isEmpty)
            XCTAssertTrue(
                technique.captureTip.lowercased().contains("frame"),
                "\(technique.rawValue) tip should reinforce full-body framing"
            )
        }
        XCTAssertFalse(MuayThaiTechnique.autoDetectCaptureTip.isEmpty)
    }

    func testFootworkDisplayName() {
        XCTAssertEqual(MuayThaiTechnique.movement.displayName, "Footwork")
    }
}
