//
//  ContentView.swift
//  Focastra
//

import SwiftUI
import Combine
import UIKit

let gradientColors: [Color] = [
    .gradientTop,
    .gradientMiddle,
    .gradientMiddle,
    .gradientBottom
]

struct ContentView: View {

    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var sessionTimer: FocusSessionTimer

    @State private var showLoading = true
    @State private var currentPage = 0

    @State private var showFailureScreen = false
    @State private var failureSession: ScheduledSession? = nil
    @State private var failureDurationMinutes: Int = 30

    // ✅ Track background time (so we can fail when app returns)
    @State private var backgroundStart: Date? = nil
    @State private var wasFocusingWhenBackgrounded = false

    // ✅ Real device lock signal (works best on iPhone)
    @State private var protectedDataUnavailable = false

    @State private var didRunRecovery = false

    let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    // ✅ Threshold: if you come back BEFORE this, we treat it like lock/unlock.
    // On Simulator, lock acts weird, so give it more time.
    private var failThresholdSeconds: Double {
        #if targetEnvironment(simulator)
        return 2.5
        #else
        return 0.8
        #endif
    }

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: gradientColors),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

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
            } else {
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
        .animation(.easeInOut(duration: 1.0), value: showLoading)

        // ✅ Lock/unlock notifications (reliable on real iPhone)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataWillBecomeUnavailableNotification)) { _ in
            protectedDataUnavailable = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataDidBecomeAvailableNotification)) { _ in
            protectedDataUnavailable = false
        }

        // ✅ Scene rules
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {

            case .active:
                // If we came back and we HAD been focusing when backgrounded, decide fail now.
                if wasFocusingWhenBackgrounded {
                    decideFailureOnReturnToActive()
                }

                // reset tracking
                backgroundStart = nil
                wasFocusingWhenBackgrounded = false

                sessionTimer.resyncIfNeeded()

            case .inactive:
                break

            case .background:
                // record background only if focusing
                if sessionTimer.isFocusing {
                    wasFocusingWhenBackgrounded = true
                    backgroundStart = Date()
                }

            @unknown default:
                break
            }
        }

        // ✅ Launch recovery (force-close)
        .task {
            if didRunRecovery { return }
            didRunRecovery = true

            runLaunchRecoveryNow()

            try? await Task.sleep(nanoseconds: 1_000_000_000)
            withAnimation { showLoading = false }
        }

        // ✅ Failure screen after force-close
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

    private func decideFailureOnReturnToActive() {
        guard let start = backgroundStart else { return }
        let away = Date().timeIntervalSince(start)

        // If away time is tiny, treat like lock/unlock → allowed
        if away < failThresholdSeconds {
            return
        }

        // Real device: if it was a lock, allow it
        #if !targetEnvironment(simulator)
        let locked = protectedDataUnavailable || (UIApplication.shared.isProtectedDataAvailable == false)
        if locked { return }
        #endif

        // Otherwise: treat as switching apps → FAIL
        failActiveSessionBecauseUserLeftApp()
    }

    // MARK: - Launch recovery (force-close)

    private func runLaunchRecoveryNow() {
        // Clean missed sessions
        var sessions = loadScheduledSessions()
        removeMissedSessionsForToday(&sessions, now: Date())
        saveScheduledSessions(sessions)

        // Snapshot-based recovery
        if var snap = loadCurrentSessionSnapshot(), snap.isActive {
            snap.isActive = false
            snap.didSucceed = false
            snap.didFail = true
            saveCurrentSessionSnapshot(snap)

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

            // ✅ IMPORTANT: show “failed” state in UI
            sessionTimer.forceFailUIState()

            showFailureScreen = true
            return
        }

        // Timer-based fallback recovery
        if sessionTimer.hadActiveTimerWhenAppClosed() {
            failureSession = nil
            failureDurationMinutes = 30

            // ✅ IMPORTANT: show “failed” state in UI
            sessionTimer.forceFailUIState()

            showFailureScreen = true
        }
    }

    // MARK: - Fail helper

    private func failActiveSessionBecauseUserLeftApp() {
        var snap = loadCurrentSessionSnapshot()
        markBackgroundFailureForSnapshot(snapshot: &snap, onFailure: {})

        sessionTimer.endEarly() // sets sessionComplete true + reward false

        if let id = snap?.scheduledSessionID {
            var sessions = loadScheduledSessions()
            if let idx = sessions.firstIndex(where: { $0.id == id }) {
                sessions[idx].status = .failed
                saveScheduledSessions(sessions)
            }
        }
    }
}
