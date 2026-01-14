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

    @State private var showFailureScreen = false
    @State private var failureSession: ScheduledSession? = nil
    @State private var failureDurationMinutes: Int = 30

    // ✅ Real-device lock signals
    @State private var protectedDataUnavailable = false

    // ✅ Cancelable failure task
    @State private var pendingFailWorkItem: DispatchWorkItem? = nil

    @State private var didRunRecovery = false

    let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    // ✅ Simulator needs longer grace window because "lock" isn't real lock
    private var backgroundFailDelay: Double {
        #if targetEnvironment(simulator)
        return 6.0
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

        // ✅ Lock/unlock notifications (real iPhone is best here)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataWillBecomeUnavailableNotification)) { _ in
            protectedDataUnavailable = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataDidBecomeAvailableNotification)) { _ in
            protectedDataUnavailable = false
        }

        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {

            case .active:
                // coming back cancels pending fail (lock/unlock should do this)
                pendingFailWorkItem?.cancel()
                pendingFailWorkItem = nil
                sessionTimer.resyncIfNeeded()

            case .inactive:
                // allowed
                break

            case .background:
                guard sessionTimer.isFocusing else { return }

                // ✅ On real devices: if locked, DO NOT fail
                #if !targetEnvironment(simulator)
                let locked = protectedDataUnavailable || (UIApplication.shared.isProtectedDataAvailable == false)
                if locked { return }
                #endif

                // Schedule fail after delay (Simulator needs longer)
                pendingFailWorkItem?.cancel()

                let work = DispatchWorkItem {
                    // If we are STILL focusing after delay, treat as leaving app
                    if sessionTimer.isFocusing {
                        failActiveSessionBecauseUserLeftApp()
                    }
                }

                pendingFailWorkItem = work
                DispatchQueue.main.asyncAfter(deadline: .now() + backgroundFailDelay, execute: work)

            @unknown default:
                break
            }
        }

        .task {
            if didRunRecovery { return }
            didRunRecovery = true

            runLaunchRecoveryNow()

            try? await Task.sleep(nanoseconds: 1_000_000_000)
            withAnimation { showLoading = false }
        }

        .fullScreenCover(isPresented: $showFailureScreen) {
            FocusSessionView(
                durationMinutes: failureDurationMinutes,
                scheduled: failureSession,
                allowStarting: false
            )
            .environmentObject(sessionTimer)
        }
    }

    // MARK: - Launch Recovery

    private func runLaunchRecoveryNow() {
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

            if sessionTimer.isFocusing {
                sessionTimer.endEarly()
            }

            showFailureScreen = true
            return
        }

        // Timer-based recovery fallback
        if sessionTimer.hadActiveTimerWhenAppClosed() {
            failureSession = nil
            failureDurationMinutes = 30

            if sessionTimer.isFocusing {
                sessionTimer.endEarly()
            }

            showFailureScreen = true
        }
    }

    // MARK: - Fail helper

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
