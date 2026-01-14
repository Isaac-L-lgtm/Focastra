//
//  ContentView.swift
//  Focastra
//
//  FINAL

// Main screen: shows welcome, tabs, and handles session recovery/failure

import SwiftUI
import Combine
import UIKit

// App background colors
let gradientColors: [Color] = [
    .gradientTop,
    .gradientMiddle,
    .gradientMiddle,
    .gradientBottom
]

// Main SwiftUI view for onboarding and tabs
struct ContentView: View {

    // Shared app state
    // - scenePhase: track whenther the app is active, inactive, or in background
    // - sessionTimer: timer data for focus sessions
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var sessionTimer: FocusSessionTimer

    // Show welcome pages first
    @State private var showLoading = true
    @State private var currentPage = 0

    // Show a full-screen fail screen when needed
    @State private var showFailureScreen = false
    @State private var failureSession: ScheduledSession? = nil
    @State private var failureDurationMinutes: Int = 30

    // Track when app went to background during a focus
    @State private var backgroundStart: Date? = nil
    @State private var wasFocusingWhenBackgrounded = false

    // True while device is locked
    @State private var protectedDataUnavailable = false

    // Run recovery only once
    @State private var didRunRecovery = false

    // Switch welcome pages every few seconds
    let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    // Small grace time: quick return does not fail.
    private var failThresholdSeconds: Double {
        #if targetEnvironment(simulator)
        return 2.5
        #else
        return 0.8
        #endif
    }

    var body: some View {
        // Background + either welcome or tabs
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: gradientColors),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Welcome pages on first load.
            if showLoading {
                TabView(selection: $currentPage) {
                    WelcomePage().tag(0)
                    FeaturesPage().tag(1)
                }
                .background(Gradient(colors: gradientColors))
                .tabViewStyle(PageTabViewStyle())
                // Auto-switch pages with animation.
                .onReceive(timer) { _ in
                    withAnimation { currentPage = (currentPage + 1) % 2 }
                }
            } else {
                // Main tabs after welcome.
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
            }
        }
        .animation(.easeInOut(duration: 1.0), value: showLoading) // Fade from welcome to tabs.

        // Detect device lock/unlock.
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataWillBecomeUnavailableNotification)) { _ in
            protectedDataUnavailable = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataDidBecomeAvailableNotification)) { _ in
            protectedDataUnavailable = false
        }

        // Runs this code when app state changes
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {

            case .active:
                // If user returns after backgrounding, check if we should fail.
                if wasFocusingWhenBackgrounded {
                    decideFailureOnReturnToActive()
                }

                // reset tracking
                backgroundStart = nil
                wasFocusingWhenBackgrounded = false

                // Update timer if app was paused
                sessionTimer.resyncIfNeeded()

            case .inactive:
                break

            case .background:
                // Track background time only during a focus
                if sessionTimer.isFocusing {
                    wasFocusingWhenBackgrounded = true
                    backgroundStart = Date()
                }

            @unknown default:
                break
            }
        }

        // On launch, recover and show failed session if needed.
        .task {
            if didRunRecovery { return }

            // Do recovery once.
            didRunRecovery = true

            runLaunchRecoveryNow()

            try? await Task.sleep(nanoseconds: 1_000_000_000)
            withAnimation { showLoading = false }
        }

        // Show failure screen when needed.
        .fullScreenCover(isPresented: $showFailureScreen) {
            FocusSessionView(
                durationMinutes: failureDurationMinutes,
                scheduled: failureSession,
                allowStarting: false
            )
            .environmentObject(sessionTimer)
        }
    }

    // MARK: - Decide failure when returning

    // Decide if coming back from background should fail
    private func decideFailureOnReturnToActive() {
        guard let start = backgroundStart else { return }
        let away = Date().timeIntervalSince(start)

        // Quick return: treat as lock/unlock (no fail)
        if away < failThresholdSeconds {
            return
        }

        // On real devices, allow screen lock
        #if !targetEnvironment(simulator)
        let locked = protectedDataUnavailable || (UIApplication.shared.isProtectedDataAvailable == false)
        if locked { return }
        #endif

        // Otherwise, user probably switched apps: fail.
        failActiveSessionBecauseUserLeftApp()
    }

    // MARK: - Launch recovery (force-close)

    // Recover after force-close/crash and prepare fail UI.
    private func runLaunchRecoveryNow() {
        // Remove today’s sessions that already passed.
        var sessions = loadScheduledSessions()
        removeMissedSessionsForToday(&sessions, now: Date())
        saveScheduledSessions(sessions)

        // Main path: recover from saved in-progress session.
        if var snap = loadCurrentSessionSnapshot(), snap.isActive {
            // Mark saved session as failed.
            snap.isActive = false
            snap.didSucceed = false
            snap.didFail = true
            saveCurrentSessionSnapshot(snap)

            // If linked to a scheduled session, mark it failed.
            if let id = snap.scheduledSessionID {
                var sessions2 = loadScheduledSessions()
                if let idx = sessions2.firstIndex(where: { $0.id == id }) {
                    sessions2[idx].status = .failed
                    saveScheduledSessions(sessions2)

                    failureSession = sessions2[idx]
                    failureDurationMinutes = sessions2[idx].durationMinutes
                } else {
                    failureSession = nil
                    failureDurationMinutes = 30
                }
            } else {
                failureSession = nil
                failureDurationMinutes = 30
            }

            // Make the timer show a failed state.
            sessionTimer.forceFailUIState()

            showFailureScreen = true
            return
        }

        // Fallback: timer was running but no saved session.
        if sessionTimer.hadActiveTimerWhenAppClosed() {
            failureSession = nil
            failureDurationMinutes = 30

            // Make the timer show a failed state.
            sessionTimer.forceFailUIState()

            showFailureScreen = true
        }
    }

    // MARK: - Fail helper

    // Fail when user leaves the app mid-session.
    private func failActiveSessionBecauseUserLeftApp() {
        // Save that this session failed.
        var snap = loadCurrentSessionSnapshot()
        markBackgroundFailureForSnapshot(snapshot: &snap, onFailure: {})

        // Stop timer and mark as no reward.
        sessionTimer.endEarly() // sets sessionComplete true + reward false

        // If there’s a scheduled session, mark it failed.
        if let id = snap?.scheduledSessionID {
            var sessions = loadScheduledSessions()
            if let idx = sessions.firstIndex(where: { $0.id == id }) {
                sessions[idx].status = .failed
                saveScheduledSessions(sessions)
            }
        }
    }
}

