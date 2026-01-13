//
//  ContentView.swift
//  Focastra
//
//  Created by Isaac Law on 2025-10-20.
//  FINAL
//

import SwiftUI
import Combine
import UIKit

// gradient colours for background.
let gradientColors: [Color] = [
    .gradientTop,
    .gradientMiddle,
    .gradientMiddle,
    .gradientBottom
]

// currentPage: 0 and 1 - loading screen
struct ContentView: View {

    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var sessionTimer: FocusSessionTimer

    @State private var showLoading = true
    @State private var currentPage = 0

    // ✅ Lock detection so lock screen DOES NOT count as leaving app
    @State private var isDeviceLocked = false

    // ✅ If app was force-closed during a session, show FocusSessionView to display failure
    @State private var showFailureScreen = false
    @State private var failureSession: ScheduledSession? = nil
    @State private var failureDurationMinutes: Int = 30

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

        // ✅ Detect lock/unlock
        .onReceive(NotificationCenter.default.publisher(
            for: UIApplication.protectedDataWillBecomeUnavailableNotification
        )) { _ in
            isDeviceLocked = true
        }
        .onReceive(NotificationCenter.default.publisher(
            for: UIApplication.protectedDataDidBecomeAvailableNotification
        )) { _ in
            isDeviceLocked = false
        }

        // ✅ GLOBAL RULE:
        // Leaving app (switch apps) fails from ANY screen, but locking phone does NOT.
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                sessionTimer.resyncIfNeeded()

            case .inactive:
                // Lock screen often triggers inactive first — allowed
                break

            case .background:
                // ✅ Lock screen should NOT fail
                if isDeviceLocked { break }

                // ✅ Switching apps should fail (from any screen)
                if sessionTimer.isFocusing {
                    failActiveSessionBecauseUserLeftApp()
                }

            @unknown default:
                break
            }
        }

        // ✅ On launch: clean missed sessions + detect force-close failure
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                withAnimation { showLoading = false }

                // Clean missed sessions
                var sessions = loadScheduledSessions()
                removeMissedSessionsForToday(&sessions, now: Date())
                saveScheduledSessions(sessions)

                // If the app was CLOSED during an active focus session -> FAIL on next launch
                if var snap = loadCurrentSessionSnapshot(), snap.isActive {
                    snap.isActive = false
                    snap.didSucceed = false
                    snap.didFail = true
                    saveCurrentSessionSnapshot(snap)

                    // Also mark scheduled session as failed and show failure screen
                    if let id = snap.scheduledSessionID {
                        var sessions2 = loadScheduledSessions()
                        if let idx = sessions2.firstIndex(where: { $0.id == id }) {
                            sessions2[idx].status = .failed
                            saveScheduledSessions(sessions2)

                            failureSession = sessions2[idx]
                            failureDurationMinutes = sessions2[idx].durationMinutes
                            showFailureScreen = true
                        }
                    }

                    // Stop timer state just in case
                    if sessionTimer.isFocusing {
                        sessionTimer.endEarly()
                    }
                }
            }
        }

        // ✅ After relaunch failure, open FocusSessionView to show "Failed"
        .fullScreenCover(isPresented: $showFailureScreen) {
            FocusSessionView(durationMinutes: failureDurationMinutes, scheduled: failureSession)
                .environmentObject(sessionTimer)
        }
    }

    // MARK: - Helper
    private func failActiveSessionBecauseUserLeftApp() {
        // Mark snapshot failure
        var snap = loadCurrentSessionSnapshot()
        markBackgroundFailureForSnapshot(snapshot: &snap, onFailure: {})

        // Stop timer
        sessionTimer.endEarly()

        // Mark scheduled session failed (if linked)
        if let id = snap?.scheduledSessionID {
            var sessions = loadScheduledSessions()
            if let idx = sessions.firstIndex(where: { $0.id == id }) {
                sessions[idx].status = .failed
                saveScheduledSessions(sessions)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(FocusSessionPlanner())
        .environmentObject(FocusSessionTimer())
}
