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

    // ✅ Protected data signals (real device lock detection)
    @State private var protectedDataUnavailable = false

    // ✅ Show failure screen after force-close
    @State private var showFailureScreen = false
    @State private var failureSession: ScheduledSession? = nil
    @State private var failureDurationMinutes: Int = 30

    // Prevent repeat recovery
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

        // ✅ These notifications help on real devices
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataWillBecomeUnavailableNotification)) { _ in
            protectedDataUnavailable = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataDidBecomeAvailableNotification)) { _ in
            protectedDataUnavailable = false
        }

        // ✅ Global: handle leaving app while focusing (from ANY screen)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {

            case .active:
                sessionTimer.resyncIfNeeded()

            case .inactive:
                // allowed (lock screen often triggers inactive first)
                break

            case .background:
                // If focusing, decide fail vs allow after a short grace delay
                if sessionTimer.isFocusing {
                    decideFailOrAllowAfterBackground()
                }

            @unknown default:
                break
            }
        }

        // ✅ Use .task so this runs when view is actually on screen (reliable cover)
        .task {
            if didRunRecovery { return }
            didRunRecovery = true

            runLaunchRecoveryNow()

            // keep your loading (still shows pages briefly)
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 sec
            withAnimation { showLoading = false }
        }

        // ✅ Always able to show failure screen after force-close
        .fullScreenCover(isPresented: $showFailureScreen) {
            FocusSessionView(durationMinutes: failureDurationMinutes, scheduled: failureSession)
                .environmentObject(sessionTimer)
        }
    }

    // MARK: - Decide fail vs allow (lock vs switch apps)

    private func decideFailOrAllowAfterBackground() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // If session already ended, do nothing
            if !sessionTimer.isFocusing { return }

            // ✅ Real device lock detection:
            // If protected data is unavailable, the phone is locked -> allow
            let lockedRealDevice =
                protectedDataUnavailable ||
                (UIApplication.shared.isProtectedDataAvailable == false)

            if lockedRealDevice {
                // Lock is allowed -> do not fail
                return
            }

            // Otherwise treat as switching apps -> fail
            failActiveSessionBecauseUserLeftApp()
        }
    }

    // MARK: - Force-close recovery

    private func runLaunchRecoveryNow() {
        // Clean missed sessions
        var sessions = loadScheduledSessions()
        removeMissedSessionsForToday(&sessions, now: Date())
        saveScheduledSessions(sessions)

        // If app was closed during an active focus session -> fail it now
        if var snap = loadCurrentSessionSnapshot(), snap.isActive {

            snap.isActive = false
            snap.didSucceed = false
            snap.didFail = true
            saveCurrentSessionSnapshot(snap)

            // Mark scheduled session failed (if linked)
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

            // Stop timer just in case
            if sessionTimer.isFocusing {
                sessionTimer.endEarly()
            }

            // ✅ Show the failure view
            DispatchQueue.main.async {
                showFailureScreen = true
            }
        }
    }

    // MARK: - Helper fail

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
