//
//  FocastraApp.swift
//  Focastra
//
//  Created by Isaac Law on 2025-10-20.
//

import SwiftUI

@main
struct FocastraApp: App {
    @StateObject private var planner = FocusSessionPlanner()
    @StateObject private var sessionTimer = FocusSessionTimer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(planner)
                .environmentObject(sessionTimer)
        }
    }
}
