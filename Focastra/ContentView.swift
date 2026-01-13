//
//  ContentView.swift
//  Focastra
//
//  Created by Isaac Law on 2025-10-20.
//  FINAL
//

import SwiftUI
import Combine

// gradient colours for background.
let gradientColors: [Color] = [
    .gradientTop,
    .gradientMiddle,
    .gradientMiddle,
    .gradientBottom
]

// currentPage: 0 and 1 - loading screen
struct ContentView: View {

    @EnvironmentObject private var sessionTimer: FocusSessionTimer

    @State private var showLoading = true
    @State private var currentPage = 0

    // every 3 seconds, auto-advance loading pages
    let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {

            LinearGradient(
                gradient: Gradient(colors: gradientColors),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Loading
            if showLoading {
                TabView(selection: $currentPage) {
                    WelcomePage().tag(0)
                    FeaturesPage().tag(1)
                }
                .background(Gradient(colors: gradientColors))
                .tabViewStyle(PageTabViewStyle())
                .onReceive(timer) { _ in
                    withAnimation {
                        currentPage = (currentPage + 1) % 2
                    }
                }
                .transition(.opacity.combined(with: .scale))
            }

            // Main App
            if !showLoading {
                TabView(selection: $currentPage) {
                    HomePage(tabSelection: $currentPage)
                        .tabItem { Label("Home", systemImage: "star.fill") }
                        .tag(0)

                    CustomizePage()
                        .tabItem { Label("Customize", systemImage: "paintbrush.pointed.fill") }
                        .tag(1)

                    StatsPage()
                        .tabItem { Label("Stats", systemImage: "chart.bar.xaxis") }
                        .tag(2)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 1.0), value: showLoading)
        .onAppear {
            // loading ends after 1 sec
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                withAnimation { showLoading = false }

                // ✅ clean missed sessions
                var sessions = loadScheduledSessions()
                removeMissedSessionsForToday(&sessions, now: Date())
                saveScheduledSessions(sessions)

                // ✅ IMPORTANT RULE:
                // If the app was CLOSED during an active focus session -> FAIL it on next launch
                if var snap = loadCurrentSessionSnapshot(), snap.isActive {

                    // Mark snapshot as failed
                    snap.isActive = false
                    snap.didSucceed = false
                    snap.didFail = true
                    saveCurrentSessionSnapshot(snap)

                    // ✅ ALSO mark the scheduled session as failed (if we know which one)
                    if let id = snap.scheduledSessionID {
                        var sessions = loadScheduledSessions()
                        if let idx = sessions.firstIndex(where: { $0.id == id }) {
                            sessions[idx].status = .failed
                            saveScheduledSessions(sessions)
                        }
                    }

                    // Stop timer state just in case
                    if sessionTimer.isFocusing {
                        sessionTimer.endEarly()
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(FocusSessionPlanner())
        .environmentObject(FocusSessionTimer())
}
