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

    // ✅ Detect when phone is locked (so lock screen does NOT count as failure)
    @State private var isDeviceLocked = false

    // ✅ If app was force-closed during a session, we open FocusSessionView to show failure
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
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataWillBecomeUnavailableNotification)) { _ in
            isDeviceLocked = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataDidBecomeAvailableNotification)) { _ in
            isDeviceLocked = false
        }

        // ✅ GLOBAL RULE:
        // If user leaves app (switch apps) while focusing -> fail (works from ANY screen)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                // If time passed while away, recompute remaining
                sessionTimer.resyncIfNeeded()

            case .inactive:
                // Lock screen / control center often triggers inactive first (allowed)
                break

            case .background:
                // ✅ If phone is locked, DO NOT fail
                if isDeviceLocked { break }

                // ✅ If user leaves app while focusing -> fail
                if sessionTimer.isFocusing {
                    failActiveSessionBecauseUserLeftApp()
                }

            @unknown default:
                break
            }
        }

        // ✅ On app launch: remove missed sessions, and detect force-close failure
        .onAppear {
            // loading ends after 1 sec
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                withAnimation { showLoading = false }

                // clean missed sessions
                var sessions = loadScheduledSessions()
                removeMissedSessionsForToday(&sessions, now: Date())
                saveScheduledSessions(sessions)

                // ✅ If the app was CLOSED during an active focus session -> FAIL it on next launch
                if var snap = loadCurrentSessionSnapshot(), snap.isActive {

                    // Mark snapshot as failed
                    snap.isActive = false
                    snap.didSucceed = false
                    snap.didFail = true
                    saveCurrentSessionSnapshot(snap)

                    // Mark the scheduled session as failed (if linked)
                    if let id = snap.scheduledSessionID {
                        var sessions2 = loadScheduledSessions()
                        if let idx = sessions2.firstIndex(where: { $0.id == id }) {
                            sessions2[idx].status = .failed
                            saveScheduledSessions(sessions2)

                            // ✅ Open FocusSessionView to SHOW failure
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

        // ✅ Show failure screen after relaunch
        .fullScreenCover(isPresented: $showFailureScreen) {
            FocusSessionView(durationMinutes: failureDurationMinutes, scheduled: failureSession)
                .environmentObject(sessionTimer)
        }
    }

    // MARK: - Helper
    private func failActiveSessionBecauseUserLeftApp() {
        // mark snapshot failure
        var snap = loadCurrentSessionSnapshot()
        markBackgroundFailureForSnapshot(snapshot: &snap, onFailure: {})

        // stop timer UI
        sessionTimer.endEarly()

        // mark scheduled session failed (if linked)
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
