//
//  MoveAIApp.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import SwiftUI

@main
struct MoveAIApp: App {
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let scenarioView = ScenarioRouter.rootView() {
                scenarioView
            } else {
                ContentView()
            }
            #else
            ContentView()
            #endif
        }
    }
}
