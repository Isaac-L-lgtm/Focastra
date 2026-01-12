//
//  FocusSessionView.swift
//  Focastra
//
//  Created by Isaac Law on 2025-11-03.
//

import SwiftUI

struct FocusSessionView: View {

    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var sessionTimer: FocusSessionTimer

    // configuration passed in
    @State private var selectedDuration: Int
    @State private var scheduledSession: ScheduledSession? = nil

    init(durationMinutes: Int = 30, scheduled: ScheduledSession? = nil) {
        _selectedDuration = State(initialValue: durationMinutes)
        _scheduledSession = State(initialValue: scheduled)
    }

    var body: some View {
        ZStack {
            VStack {
                Text("Focus Session")
                    .font(.custom("Impact", size: 60))
                    .fontWeight(.bold)
                    .padding(.top, 100)
                    .padding(.bottom, 100)

                // Timer display
                Text(formatTime(sessionTimer.timeRemaining))
                    .font(.custom("Impact", size: 60))
                    .fontWeight(.bold)
                    .padding(.bottom, 50)

                // Start button (only starts when rules are met)
                Button {
                    // already focusing? do nothing
                    if sessionTimer.isFocusing { return }

                    // cannot restart completed/failed session
                    if let sched = scheduledSession, (sched.status == .completed || sched.status == .failed) {
                        return
                    }

                    // ✅ Start allowed only if:
                    // - date is today
                    // - time is coming up (now must be <= scheduled time)
                    if let sched = scheduledSession {
                        let now = Date()
                        let cal = Calendar.current

                        if !cal.isDate(sched.scheduledDate, inSameDayAs: now) {
                            return
                        }

                        if now > sched.scheduledDate {
                            // missed it (HomePage will remove it anyway)
                            return
                        }
                    }

                    // Start timer
                    sessionTimer.start(durationMinutes: selectedDuration)

                    // Save snapshot so we can restore if app restarts
                    let snapshot = makeCurrentSessionSnapshot(durationMinutes: selectedDuration, start: Date())
                    saveCurrentSessionSnapshot(snapshot)

                } label: {
                    Text(sessionTimer.isFocusing ? "Focusing..." : "Start Focus Session")
                        .font(.custom("Impact", size: 40))
                        .padding()
                        .background(.focastra, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                        .opacity(sessionTimer.isFocusing ? 0.6 : 1.0)
                }
                .disabled(sessionTimer.isFocusing || (scheduledSession?.status == .completed) || (scheduledSession?.status == .failed))

                // encouragement
                if sessionTimer.isFocusing {
                    Text("Stay focused for \(selectedDuration) minutes!")
                        .font(.headline)
                        .padding(.top, 20)
                }

                // complete message
                if sessionTimer.sessionComplete {
                    Text(sessionTimer.rewardEarned ? "✅ Session Complete! Reward Earned!" : "⛔ Session Failed / Ended Early.\nNo reward.")
                        .font(.headline)
                        .padding(.top, 20)
                        .multilineTextAlignment(.center)
                }

                Spacer()
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(edges: .bottom)
        .background(Gradient(colors: gradientColors))

        // ✅ Restore timer when reopening app (lock screen is OK)
        .onAppear {
            // If not currently focusing, show full duration by default
            if !sessionTimer.isFocusing {
                sessionTimer.timeRemaining = selectedDuration * 60
            }

            // If snapshot says we were focusing before, restore the timer
            if let snap = loadCurrentSessionSnapshot(), snap.isActive {
                sessionTimer.restoreFromEndDate(snap.endDate)
            }
        }

        // ✅ When the session ends: mark scheduled session complete/failed + snapshot handling
        .onChange(of: sessionTimer.sessionComplete) { _, isComplete in
            if !isComplete { return }

            // update scheduled session status
            if let sched = scheduledSession {
                var sessions = loadScheduledSessions()
                if let idx = sessions.firstIndex(where: { $0.id == sched.id }) {
                    sessions[idx].status = sessionTimer.rewardEarned ? .completed : .failed
                    saveScheduledSessions(sessions)
                }
            }

            // snapshot rules:
            // - success -> clear snapshot
            // - failure -> keep snapshot (so failure state can be shown)
            if sessionTimer.rewardEarned {
                saveCurrentSessionSnapshot(nil)
            }
        }

        // ✅ Background = failure, Lock screen = allowed
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {

            case .active:
                // resync timer in case time passed
                sessionTimer.resyncIfNeeded()

                // handle snapshot when returning active
                var snap = loadCurrentSessionSnapshot()
                handleScenePhaseForSnapshot(
                    snapshot: &snap,
                    onActive: {
                        // no-op
                    },
                    onSuccess: {
                        // if it ended while away, complete
                        if sessionTimer.isFocusing {
                            sessionTimer.completeSession()
                        }
                    },
                    onFailure: {
                        // failure is handled on background below
                    },
                    now: Date()
                )

            case .inactive:
                // lock screen / control center happens here (allowed)
                break

            case .background:
                // ✅ if focusing and user leaves app -> immediate failure
                if sessionTimer.isFocusing {
                    var snap = loadCurrentSessionSnapshot()
                    markBackgroundFailureForSnapshot(snapshot: &snap, onFailure: {})
                    sessionTimer.endEarly()

                    // mark scheduled as failed
                    if let sched = scheduledSession {
                        var sessions = loadScheduledSessions()
                        if let idx = sessions.firstIndex(where: { $0.id == sched.id }) {
                            sessions[idx].status = .failed
                            saveScheduledSessions(sessions)
                        }
                    }
                }

            @unknown default:
                break
            }
        }
    }

    func formatTime(_ seconds: Int) -> String {
        let hrs = seconds / 3600
        let mins = (seconds % 3600) / 60
        let secs = seconds % 60

        if hrs > 0 {
            return String(format: "%d:%02d:%02d", hrs, mins, secs)
        } else {
            return String(format: "%02d:%02d", mins, secs)
        }
    }
}

#Preview {
    FocusSessionView()
        .environmentObject(FocusSessionTimer())
}
