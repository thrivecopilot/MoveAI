//
//  MuayThaiSelectionMemory.swift
//  MoveAI
//
//  Remembers the user's last Muay Thai picker choices so repeat sessions are
//  one tap. First launch defaults to Auto Detect (the safe cold-start: a wrong
//  manual technique produces confidently wrong coaching).
//

import Foundation

struct MuayThaiSelectionMemory: Equatable {
    static let autoDetectKey = "muayThai_lastUseAutoDetect"
    static let techniqueKey = "muayThai_lastTechnique"
    static let stanceKey = "muayThai_lastStance"

    let useAutoDetect: Bool
    let technique: MuayThaiTechnique
    let stance: FightStance

    static func load(from defaults: UserDefaults = .standard) -> MuayThaiSelectionMemory {
        let useAutoDetect = defaults.object(forKey: autoDetectKey) as? Bool ?? true
        let technique = defaults.string(forKey: techniqueKey)
            .flatMap(MuayThaiTechnique.init(rawValue:)) ?? .jab
        let stance = defaults.string(forKey: stanceKey)
            .flatMap(FightStance.init(rawValue:)) ?? .unknown
        return MuayThaiSelectionMemory(useAutoDetect: useAutoDetect, technique: technique, stance: stance)
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(useAutoDetect, forKey: Self.autoDetectKey)
        defaults.set(technique.rawValue, forKey: Self.techniqueKey)
        defaults.set(stance.rawValue, forKey: Self.stanceKey)
    }
}
