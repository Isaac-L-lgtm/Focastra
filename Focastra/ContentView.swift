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

    // Failure screen after force-close
    @State private var showFailureScreen = false
    @State private var failureSession: ScheduledSession? = nil
    @State private var failureDurationMinutes: Int = 30

    // ✅ Background grace (helps lock/unlock not count as app switch on Simulator)
    @State private var pendingBackgroundFail = false

    // Run recovery only once
    @State private var didRunRecovery = false

    let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

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
                .transition(.opacity.combined(with: .scale))
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
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 1.0), value: showLoading)

        // ✅ Scene phase rules
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                // If we come back quickly (lock/unlock), cancel the pending failure
                pendingBackgroundFail = false
                sessionTimer.resyncIfNeeded()

            case .inactive:
                // allowed
                break

            case .background:
                // If focusing, schedule a fail shortly.
                // If user locks/unlocks quickly, we'll cancel when it goes active.
                if sessionTimer.isFocusing {
                    pendingBackgroundFail = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        // If still pending and still focusing, treat as leaving app and fail.
                        if pendingBackgroundFail && sessionTimer.isFocusing {
                            failActiveSessionBecauseUserLeftApp()
                        }
                    }
                }

            @unknown default:
                break
            }
        }

        // ✅ Run recovery reliably (after view appears) using .task
        .task {
            if didRunRecovery { return }
            didRunRecovery = true

            runLaunchRecoveryNow()

            // loading ends after 1 sec
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            withAnimation { showLoading = false }
        }

        // Show failure screen (force-close)
        .fullScreenCover(isPresented: $showFailureScreen) {
            FocusSessionView(durationMinutes: failureDurationMinutes, scheduled: failureSession)
                .environmentObject(sessionTimer)
        }
    }

    // MARK: - Launch Recovery (force-close)

    private func runLaunchRecoveryNow() {
        // Clean missed sessions
        var sessions = loadScheduledSessions()
        removeMissedSessionsForToday(&sessions, now: Date())
        saveScheduledSessions(sessions)

        // ✅ Case A: Snapshot says it was active
        if var snap = loadCurrentSessionSnapshot(), snap.isActive {
            markForceCloseFailureFromSnapshot(snap: &snap)
            return
        }

        // ✅ Case B: Snapshot failed to save, but Timer persistence says it was active
        if sessionTimer.hadActiveTimerWhenAppClosed() {
            // Mark snapshot as failed (generic)
            var generic = loadCurrentSessionSnapshot()
            markBackgroundFailureForSnapshot(snapshot: &generic, onFailure: {})
            saveCurrentSessionSnapshot(generic)

            // We may not know which scheduled session ID, so show generic failure screen
            failureSession = nil
            failureDurationMinutes = 30
            showFailureScreen = true

            // Ensure timer UI stops
            if sessionTimer.isFocusing {
                sessionTimer.endEarly()
            }
        }
    }

    private func markForceCloseFailureFromSnapshot(snap: inout PersistedCurrentSession) {
        // Mark snapshot as failed
        snap.isActive = false
        snap.didSucceed = false
        snap.didFail = true
        saveCurrentSessionSnapshot(snap)

        // Mark scheduled session failed + open failure screen
        if let id = snap.scheduledSessionID {
            var sessions2 = loadScheduledSessions()
            if let idx = sessions2.firstIndex(where: { $0.id == id }) {
                sessions2[idx].status = .failed
                saveScheduledSessions(sessions2)

                failureSession = sessions2[idx]
                failureDurationMinutes = sessions2[idx].durationMinutes
                showFailureScreen = true
            } else {
                failureSession = nil
                failureDurationMinutes = 30
                showFailureScreen = true
            }
        } else {
            failureSession = nil
            failureDurationMinutes = 30
            showFailureScreen = true
        }

        if sessionTimer.isFocusing {
            sessionTimer.endEarly()
        }
    }

    // MARK: - Helper: fail on leaving app

    private func failActiveSessionBecauseUserLeftApp() {
        var snap = loadCurrentSessionSnapshot()
        markBackgroundFailureForSnapshot(snapshot: &snap, onFailure: {})

        sessionTimer.endEarly()

        if let id = snap?.scheduledSessionID {
            var sessions = loadScheduledSessions()
            if let idx = sessions.firstIndex(where: { $0.id == id }) {
                sessions[idx].status = .failed
                saveScheduledSessions(sessions)
            }
        }
    }
}
