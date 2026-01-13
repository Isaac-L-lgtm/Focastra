//
//  FocusSessionView.swift
//  Focastra
//
//  Created by Isaac Law on 2025-11-03.
//

import SwiftUI

struct FocusSessionView: View {

    @EnvironmentObject private var sessionTimer: FocusSessionTimer

    @State private var selectedDuration: Int
    @State private var scheduledSession: ScheduledSession? = nil

    init(durationMinutes: Int = 30, scheduled: ScheduledSession? = nil) {
        _selectedDuration = State(initialValue: durationMinutes)
        _scheduledSession = State(initialValue: scheduled)
    }

    // ✅ Hide start if this session is already completed/failed OR session already ended
    private var shouldShowStart: Bool {
        if sessionTimer.isFocusing { return false }
        if sessionTimer.sessionComplete { return false }
        if let s = scheduledSession {
            return s.status == .scheduled
        }
        return true
    }

    var body: some View {
        ZStack {
            VStack {
                Text("Focus Session")
                    .font(.custom("Impact", size: 60))
                    .fontWeight(.bold)
                    .padding(.top, 100)
                    .padding(.bottom, 100)

                Text(formatTime(sessionTimer.timeRemaining))
                    .font(.custom("Impact", size: 60))
                    .fontWeight(.bold)
                    .padding(.bottom, 50)

                // ✅ Start button (hidden when failed/completed)
                if shouldShowStart {
                    Button {
                        if sessionTimer.isFocusing { return }

                        // cannot restart completed/failed session
                        if let sched = scheduledSession, (sched.status == .completed || sched.status == .failed) {
                            return
                        }

                        // Start allowed only if today and time hasn't passed
                        if let sched = scheduledSession {
                            let now = Date()
                            let cal = Calendar.current

                            if !cal.isDate(sched.scheduledDate, inSameDayAs: now) { return }
                            if now > sched.scheduledDate { return }
                        }

                        sessionTimer.start(durationMinutes: selectedDuration)

                        let snapshot = makeCurrentSessionSnapshot(
                            durationMinutes: selectedDuration,
                            start: Date(),
                            scheduledSessionID: scheduledSession?.id
                        )
                        saveCurrentSessionSnapshot(snapshot)

                    } label: {
                        Text("Start Focus Session")
                            .font(.custom("Impact", size: 40))
                            .padding()
                            .background(.focastra, in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.white)
                    }
                }

                if sessionTimer.isFocusing {
                    Text("Stay focused for \(selectedDuration) minutes!")
                        .font(.headline)
                        .padding(.top, 20)
                }

                if sessionTimer.sessionComplete {
                    Text(sessionTimer.rewardEarned
                         ? "✅ Session Complete! Reward Earned!"
                         : "⛔ Session Failed.\nNo reward.")
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

        .onAppear {
            // Show full duration if not focusing yet
            if !sessionTimer.isFocusing && !sessionTimer.sessionComplete {
                sessionTimer.timeRemaining = selectedDuration * 60
            }

            // ✅ Read snapshot state to restore OR show fail after relaunch
            if let snap = loadCurrentSessionSnapshot() {
                if snap.isActive {
                    sessionTimer.restoreFromEndDate(snap.endDate)
                } else if snap.didFail {
                    sessionTimer.isFocusing = false
                    sessionTimer.sessionComplete = true
                    sessionTimer.rewardEarned = false
                    sessionTimer.timeRemaining = 0
                } else if snap.didSucceed {
                    sessionTimer.isFocusing = false
                    sessionTimer.sessionComplete = true
                    sessionTimer.rewardEarned = true
                    sessionTimer.timeRemaining = 0
                }
            }

            // ✅ Reload the latest scheduled session status from storage (so Start hides after fail)
            if let s = scheduledSession {
                let sessions = loadScheduledSessions()
                if let newest = sessions.first(where: { $0.id == s.id }) {
                    scheduledSession = newest
                    selectedDuration = newest.durationMinutes
                }
            }
        }

        // When session ends: mark scheduled session completed/failed
        .onChange(of: sessionTimer.sessionComplete) { _, isComplete in
            if !isComplete { return }

            if let sched = scheduledSession {
                var sessions = loadScheduledSessions()
                if let idx = sessions.firstIndex(where: { $0.id == sched.id }) {
                    sessions[idx].status = sessionTimer.rewardEarned ? .completed : .failed
                    saveScheduledSessions(sessions)
                    scheduledSession = sessions[idx]
                }
            }

            // success -> clear snapshot; failure -> keep snapshot (so we can show fail)
            if sessionTimer.rewardEarned {
                saveCurrentSessionSnapshot(nil)
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
