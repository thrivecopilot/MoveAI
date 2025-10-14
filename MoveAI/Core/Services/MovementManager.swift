//
//  MovementManager.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import Foundation
import SwiftUI

@MainActor
class MovementManager: ObservableObject {
    @Published var movements: [Movement] = []
    // Goals functionality removed - focusing on core movement tracking
    @Published var selectedMovement: Movement?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let userDefaults = UserDefaults.standard
    private let movementsKey = "savedMovements"
    // Goals functionality removed
    
    init() {
        loadMovements()
        // Goals functionality removed
        setupDefaultMovements()
    }
    
    // MARK: - Movement Management
    
    func loadMovements() {
        if let data = userDefaults.data(forKey: movementsKey),
           let savedMovements = try? JSONDecoder().decode([Movement].self, from: data) {
            movements = savedMovements
        }
    }
    
    func saveMovements() {
        if let data = try? JSONEncoder().encode(movements) {
            userDefaults.set(data, forKey: movementsKey)
        }
    }
    
    func addMovement(_ movement: Movement) {
        movements.append(movement)
        saveMovements()
    }
    
    func updateMovement(_ movement: Movement) {
        if let index = movements.firstIndex(where: { $0.id == movement.id }) {
            movements[index] = movement
            saveMovements()
        }
    }
    
    func deleteMovement(_ movement: Movement) {
        movements.removeAll { $0.id == movement.id }
        saveMovements()
    }
    
    // MARK: - Goal Management
    
    // Goals functionality removed - focusing on core movement tracking
    
    // MARK: - Search and Filtering
    
    func searchMovements(_ query: String) -> [Movement] {
        if query.isEmpty {
            return movements
        }
        
        return movements.filter { movement in
            movement.name.localizedCaseInsensitiveContains(query) ||
            movement.description.localizedCaseInsensitiveContains(query) ||
            movement.category.rawValue.localizedCaseInsensitiveContains(query)
        }
    }
    
    func getMovementsByCategory(_ category: MovementCategory) -> [Movement] {
        return movements.filter { $0.category == category }
    }
    
    func getMovementsByDifficulty(_ difficulty: DifficultyLevel) -> [Movement] {
        return movements.filter { $0.difficulty == difficulty }
    }
    
    // MARK: - Default Data Setup
    
    private func setupDefaultMovements() {
        if movements.isEmpty {
            movements = createDefaultPowerliftingMovements()
            saveMovements()
        }
    }
    
    private func createDefaultPowerliftingMovements() -> [Movement] {
        return [
            createSquatMovement(),
            createDeadliftMovement(),
            createBenchPressMovement(),
            createOverheadPressMovement(),
            createBarbellRowMovement()
        ]
    }
    
    private func createSquatMovement() -> Movement {
        return Movement(
            name: "Barbell Back Squat",
            category: .powerlifting,
            description: "The king of lower body exercises, targeting quadriceps, glutes, and hamstrings.",
            keyPoints: [
                KeyPoint(
                    joint: .knee,
                    position: .flexed,
                    importance: .high,
                    mentalCue: "Break at the hips first, then knees",
                    correctiveExercise: "Box squats for depth control",
                    description: "Knees should track over toes, not cave inward"
                ),
                KeyPoint(
                    joint: .spine,
                    position: .neutral,
                    importance: .critical,
                    mentalCue: "Chest up, core tight",
                    correctiveExercise: "Planks and dead bugs",
                    description: "Maintain neutral spine throughout the movement"
                ),
                KeyPoint(
                    joint: .hip,
                    position: .flexed,
                    importance: .high,
                    mentalCue: "Hip crease below knee cap",
                    correctiveExercise: "Ankle mobility drills",
                    description: "Achieve proper depth for full range of motion"
                )
            ],
            idealForm: IdealForm(
                jointAngles: [
                    .knee: 90.0,
                    .hip: 45.0,
                    .ankle: 15.0
                ],
                bodyPositions: [
                    "torso_upright": 0.8,
                    "knee_tracking": 0.9
                ],
                timing: [
                    "descent": 2.0,
                    "ascent": 1.5
                ],
                breathingPattern: "Inhale on descent, exhale on ascent",
                setupInstructions: [
                    "Position bar on upper traps",
                    "Feet shoulder-width apart",
                    "Toes slightly pointed out",
                    "Take a deep breath and brace core"
                ]
            ),
            difficulty: .intermediate,
            equipment: [.barbell, .plates, .rack, .belt],
            instructions: [
                "Unrack the bar and step back",
                "Take a deep breath and brace your core",
                "Initiate the movement by breaking at the hips",
                "Descend until hip crease is below knee cap",
                "Drive through heels to return to standing"
            ],
            commonMistakes: [
                CommonMistake(
                    name: "Knee Valgus",
                    description: "Knees caving inward during the squat",
                    severity: .moderate,
                    affectedJoints: [.knee],
                    correction: "Focus on pushing knees out over toes",
                    prevention: "Strengthen hip abductors and improve ankle mobility"
                ),
                CommonMistake(
                    name: "Forward Lean",
                    description: "Excessive forward lean during the squat",
                    severity: .moderate,
                    affectedJoints: [.spine, .hip],
                    correction: "Keep chest up and core tight",
                    prevention: "Strengthen upper back and core muscles"
                )
            ]
        )
    }
    
    private func createDeadliftMovement() -> Movement {
        return Movement(
            name: "Conventional Deadlift",
            category: .powerlifting,
            description: "A compound movement targeting the posterior chain including hamstrings, glutes, and back.",
            keyPoints: [
                KeyPoint(
                    joint: .spine,
                    position: .neutral,
                    importance: .critical,
                    mentalCue: "Chest up, shoulders over bar",
                    correctiveExercise: "Rack pulls and Romanian deadlifts",
                    description: "Maintain neutral spine throughout the entire movement"
                ),
                KeyPoint(
                    joint: .hip,
                    position: .extended,
                    importance: .high,
                    mentalCue: "Drive hips forward to lockout",
                    correctiveExercise: "Hip thrusts and glute bridges",
                    description: "Full hip extension at the top of the movement"
                )
            ],
            idealForm: IdealForm(
                jointAngles: [
                    .hip: 30.0,
                    .knee: 45.0,
                    .spine: 0.0
                ],
                bodyPositions: [
                    "shoulders_over_bar": 0.9,
                    "bar_close_to_body": 0.95
                ],
                timing: [
                    "lift": 2.0,
                    "lower": 3.0
                ],
                breathingPattern: "Inhale and brace before lift, exhale at lockout",
                setupInstructions: [
                    "Stand with feet hip-width apart",
                    "Bar over mid-foot",
                    "Grip bar just outside legs",
                    "Chest up, shoulders over bar"
                ]
            ),
            difficulty: .intermediate,
            equipment: [.barbell, .plates, .belt, .chalk],
            instructions: [
                "Set up with bar over mid-foot",
                "Grip bar just outside your legs",
                "Chest up, shoulders over the bar",
                "Take a deep breath and brace",
                "Drive through heels and extend hips"
            ],
            commonMistakes: [
                CommonMistake(
                    name: "Rounded Back",
                    description: "Spinal flexion during the deadlift",
                    severity: .dangerous,
                    affectedJoints: [.spine],
                    correction: "Stop and reset with proper form",
                    prevention: "Strengthen core and posterior chain"
                )
            ]
        )
    }
    
    private func createBenchPressMovement() -> Movement {
        return Movement(
            name: "Barbell Bench Press",
            category: .powerlifting,
            description: "Upper body compound movement targeting chest, shoulders, and triceps.",
            keyPoints: [
                KeyPoint(
                    joint: .shoulder,
                    position: .neutral,
                    importance: .high,
                    mentalCue: "Shoulder blades back and down",
                    correctiveExercise: "Face pulls and band pull-aparts",
                    description: "Retract and depress shoulder blades"
                ),
                KeyPoint(
                    joint: .elbow,
                    position: .flexed,
                    importance: .medium,
                    mentalCue: "Control the descent",
                    correctiveExercise: "Pause bench press",
                    description: "Controlled eccentric phase"
                )
            ],
            idealForm: IdealForm(
                jointAngles: [
                    .elbow: 90.0,
                    .shoulder: 45.0
                ],
                bodyPositions: [
                    "shoulder_blades_retracted": 0.9,
                    "feet_planted": 0.95
                ],
                timing: [
                    "descent": 2.0,
                    "ascent": 1.0
                ],
                breathingPattern: "Inhale on descent, exhale on ascent",
                setupInstructions: [
                    "Lie on bench with eyes under the bar",
                    "Retract shoulder blades",
                    "Plant feet firmly on floor",
                    "Create arch in lower back"
                ]
            ),
            difficulty: .intermediate,
            equipment: [.barbell, .plates, .bench, .belt],
            instructions: [
                "Set up with proper arch and foot position",
                "Unrack the bar with straight arms",
                "Lower bar to chest with control",
                "Press bar up in straight line",
                "Rack the bar safely"
            ],
            commonMistakes: [
                CommonMistake(
                    name: "Bouncing",
                    description: "Bouncing the bar off the chest",
                    severity: .moderate,
                    affectedJoints: [.chest, .shoulder],
                    correction: "Control the descent and pause",
                    prevention: "Practice pause bench press"
                )
            ]
        )
    }
    
    private func createOverheadPressMovement() -> Movement {
        return Movement(
            name: "Overhead Press",
            category: .powerlifting,
            description: "Vertical pressing movement targeting shoulders, triceps, and core stability.",
            keyPoints: [
                KeyPoint(
                    joint: .shoulder,
                    position: .neutral,
                    importance: .high,
                    mentalCue: "Press straight up, not forward",
                    correctiveExercise: "Wall slides and band pull-aparts",
                    description: "Vertical pressing pattern"
                )
            ],
            idealForm: IdealForm(
                jointAngles: [
                    .shoulder: 90.0,
                    .elbow: 45.0
                ],
                bodyPositions: [
                    "bar_over_shoulders": 0.9,
                    "core_braced": 0.95
                ],
                timing: [
                    "press": 1.5,
                    "lower": 2.0
                ],
                breathingPattern: "Inhale before press, exhale during press",
                setupInstructions: [
                    "Start with bar at shoulder level",
                    "Grip slightly wider than shoulders",
                    "Brace core and glutes",
                    "Press straight up"
                ]
            ),
            difficulty: .intermediate,
            equipment: [.barbell, .plates],
            instructions: [
                "Start with bar at shoulder level",
                "Grip slightly wider than shoulders",
                "Brace core and glutes",
                "Press bar straight up overhead",
                "Lower with control"
            ],
            commonMistakes: []
        )
    }
    
    private func createBarbellRowMovement() -> Movement {
        return Movement(
            name: "Barbell Row",
            category: .accessory,
            description: "Horizontal pulling movement targeting the back, biceps, and rear delts.",
            keyPoints: [
                KeyPoint(
                    joint: .shoulder,
                    position: .retracted,
                    importance: .high,
                    mentalCue: "Pull elbows back, not up",
                    correctiveExercise: "Face pulls and band rows",
                    description: "Horizontal pulling pattern"
                )
            ],
            idealForm: IdealForm(
                jointAngles: [
                    .elbow: 90.0,
                    .shoulder: 45.0
                ],
                bodyPositions: [
                    "torso_parallel": 0.8,
                    "bar_to_chest": 0.9
                ],
                timing: [
                    "pull": 1.0,
                    "lower": 2.0
                ],
                breathingPattern: "Exhale on pull, inhale on lower",
                setupInstructions: [
                    "Stand with feet hip-width apart",
                    "Hinge at hips to parallel",
                    "Grip bar with overhand grip",
                    "Pull bar to lower chest"
                ]
            ),
            difficulty: .intermediate,
            equipment: [.barbell, .plates],
            instructions: [
                "Set up with bar on floor",
                "Hinge at hips to parallel position",
                "Grip bar with overhand grip",
                "Pull bar to lower chest",
                "Lower with control"
            ],
            commonMistakes: []
        )
    }
}

