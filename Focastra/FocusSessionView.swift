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

    private var canShowStartButton: Bool {
        if sessionTimer.isFocusing { return false }
        if sessionTimer.sessionComplete { return false }
        if let s = scheduledSession { return s.status == .scheduled }
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

                if canShowStartButton {
                    Button {
                        if sessionTimer.isFocusing { return }

                        if let sched = scheduledSession,
                           (sched.status == .completed || sched.status == .failed) {
                            return
                        }

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
            if let s = scheduledSession {
                let sessions = loadScheduledSessions()
                if let newest = sessions.first(where: { $0.id == s.id }) {
                    scheduledSession = newest
                    selectedDuration = newest.durationMinutes
                }
            }

            if let s = scheduledSession, s.status == .scheduled {
                sessionTimer.isFocusing = false
                sessionTimer.sessionComplete = false
                sessionTimer.rewardEarned = false
                sessionTimer.timeRemaining = selectedDuration * 60
            } else if scheduledSession == nil {
                if !sessionTimer.isFocusing && !sessionTimer.sessionComplete {
                    sessionTimer.timeRemaining = selectedDuration * 60
                }
            }

            if let snap = loadCurrentSessionSnapshot() {
                let matchesThisSession = (snap.scheduledSessionID != nil &&
                                          snap.scheduledSessionID == scheduledSession?.id)

                if snap.isActive && matchesThisSession {
                    sessionTimer.restoreFromEndDate(snap.endDate)
                } else if snap.didFail && matchesThisSession {
                    sessionTimer.isFocusing = false
                    sessionTimer.sessionComplete = true
                    sessionTimer.rewardEarned = false
                    sessionTimer.timeRemaining = 0
                    saveCurrentSessionSnapshot(nil)
                } else if snap.didSucceed && matchesThisSession {
                    sessionTimer.isFocusing = false
                    sessionTimer.sessionComplete = true
                    sessionTimer.rewardEarned = true
                    sessionTimer.timeRemaining = 0
                    saveCurrentSessionSnapshot(nil)
                }
            }
        }

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

            saveCurrentSessionSnapshot(nil)
        }
    }

    private func formatTime(_ seconds: Int) -> String {
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
