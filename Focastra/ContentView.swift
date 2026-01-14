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

    // ✅ For showing failure screen after force-close
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

        // ✅ Global rule: leaving app fails from ANY screen, but locking phone does NOT.
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                sessionTimer.resyncIfNeeded()

            case .inactive:
                // allowed (lock screen often hits inactive first)
                break

            case .background:
                // ✅ Reliable lock check:
                // When phone is locked, protected data becomes unavailable.
                let locked = (UIApplication.shared.isProtectedDataAvailable == false)
                if locked { break }

                // ✅ If user actually left the app while focusing -> fail
                if sessionTimer.isFocusing {
                    failActiveSessionBecauseUserLeftApp()
                }

            @unknown default:
                break
            }
        }

        // ✅ On launch: do recovery IMMEDIATELY (before loading delay)
        .onAppear {
            runLaunchRecovery()

            // loading ends after 1 sec
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                withAnimation { showLoading = false }
            }
        }

        // ✅ Show failure screen after force-close
        // (This can show even while loading is on screen)
        .fullScreenCover(isPresented: $showFailureScreen) {
            FocusSessionView(durationMinutes: failureDurationMinutes, scheduled: failureSession)
                .environmentObject(sessionTimer)
        }
    }

    // MARK: - Launch Recovery

    private func runLaunchRecovery() {
        // Clean missed sessions
        var sessions = loadScheduledSessions()
        removeMissedSessionsForToday(&sessions, now: Date())
        saveScheduledSessions(sessions)

        // If app was CLOSED during an active focus session -> fail it now
        if var snap = loadCurrentSessionSnapshot(), snap.isActive {

            // Mark snapshot as failed
            snap.isActive = false
            snap.didSucceed = false
            snap.didFail = true
            saveCurrentSessionSnapshot(snap)

            // Mark scheduled session as failed and prepare to show FocusSessionView
            if let id = snap.scheduledSessionID {
                var sessions2 = loadScheduledSessions()
                if let idx = sessions2.firstIndex(where: { $0.id == id }) {
                    sessions2[idx].status = .failed
                    saveScheduledSessions(sessions2)

                    failureSession = sessions2[idx]
                    failureDurationMinutes = sessions2[idx].durationMinutes
                    showFailureScreen = true
                } else {
                    // If we couldn't find the session, still show a generic failure screen
                    failureSession = nil
                    failureDurationMinutes = 30
                    showFailureScreen = true
                }
            } else {
                // No linked scheduled ID -> still show failure screen
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
