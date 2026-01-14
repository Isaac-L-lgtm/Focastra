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

    // ✅ More reliable lock signal (notifications can be flaky on Simulator)
    @State private var protectedDataUnavailable = false

    // ✅ Show failure screen after force-close
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
                    withAnimation { currentPage = (currentPage + 1) % 2 }
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

        // ✅ Lock/unlock notifications (helpful when they work)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataWillBecomeUnavailableNotification)) { _ in
            protectedDataUnavailable = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataDidBecomeAvailableNotification)) { _ in
            protectedDataUnavailable = false
        }

        // ✅ GLOBAL RULES:
        // - switching apps -> fail
        // - locking phone -> allowed
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                sessionTimer.resyncIfNeeded()

            case .inactive:
                // Lock screen / control center often triggers inactive first (allowed)
                break

            case .background:
                // If we're focusing, decide whether this background should fail.
                if sessionTimer.isFocusing {
                    decideFailOrAllowAfterBackground()
                }

            @unknown default:
                break
            }
        }

        // ✅ Run recovery IMMEDIATELY on launch (force-close detection)
        .onAppear {
            runLaunchRecoveryNow()

            // keep your loading behavior
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                withAnimation { showLoading = false }
            }
        }

        // ✅ Show failure screen after relaunch
        // (this can appear even while loading is shown)
        .fullScreenCover(isPresented: $showFailureScreen) {
            FocusSessionView(durationMinutes: failureDurationMinutes, scheduled: failureSession)
                .environmentObject(sessionTimer)
        }
    }

    // MARK: - Background decision

    private func decideFailOrAllowAfterBackground() {
        // Wait a bit so lock signals can update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            // If session already ended, do nothing
            if !sessionTimer.isFocusing { return }

            // ✅ Strong lock check:
            // When locked, protected data is unavailable.
            let locked =
                protectedDataUnavailable ||
                (UIApplication.shared.isProtectedDataAvailable == false)

            if locked {
                // Lock is allowed -> do not fail
                return
            }

            // Otherwise treat as switching apps -> fail
            failActiveSessionBecauseUserLeftApp()
        }
    }

    // MARK: - Launch recovery (force-close)

    private func runLaunchRecoveryNow() {
        // Clean missed sessions
        var sessions = loadScheduledSessions()
        removeMissedSessionsForToday(&sessions, now: Date())
        saveScheduledSessions(sessions)

        // If app was closed during an active focus session -> fail it now
        if var snap = loadCurrentSessionSnapshot(), snap.isActive {

            // Mark snapshot as failed
            snap.isActive = false
            snap.didSucceed = false
            snap.didFail = true
            saveCurrentSessionSnapshot(snap)

            // Mark scheduled session failed if linked
            if let id = snap.scheduledSessionID {
                var sessions2 = loadScheduledSessions()
                if let idx = sessions2.firstIndex(where: { $0.id == id }) {
                    sessions2[idx].status = .failed
                    saveScheduledSessions(sessions2)

                    failureSession = sessions2[idx]
                    failureDurationMinutes = sessions2[idx].durationMinutes
                    showFailureScreen = true
                } else {
                    // Can't find session, still show failure screen
                    failureSession = nil
                    failureDurationMinutes = 30
                    showFailureScreen = true
                }
            } else {
                // No ID, still show failure screen
                failureSession = nil
                failureDurationMinutes = 30
                showFailureScreen = true
            }

            // Stop timer state just in case
            if sessionTimer.isFocusing {
                sessionTimer.endEarly()
            }
        }
    }

    // MARK: - Helper fail

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
