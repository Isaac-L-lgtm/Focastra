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

    private var canStart: Bool {
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
                    .padding(.top, 100)
                    .padding(.bottom, 100)

                Text(formatTime(sessionTimer.timeRemaining))
                    .font(.custom("Impact", size: 60))
                    .padding(.bottom, 50)

                if canStart {
                    Button {
                        if sessionTimer.isFocusing { return }

                        if let s = scheduledSession, (s.status == .failed || s.status == .completed) {
                            return
                        }

                        if let s = scheduledSession {
                            let now = Date()
                            let cal = Calendar.current
                            if !cal.isDate(s.scheduledDate, inSameDayAs: now) { return }
                            if now > s.scheduledDate { return }
                        }

                        sessionTimer.start(durationMinutes: selectedDuration)

                        let snap = makeCurrentSessionSnapshot(
                            durationMinutes: selectedDuration,
                            start: Date(),
                            scheduledSessionID: scheduledSession?.id
                        )
                        saveCurrentSessionSnapshot(snap)

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
        .ignoresSafeArea()
        .background(Gradient(colors: gradientColors))

        .onAppear {
            // Reload session from storage so status is correct
            if let s = scheduledSession {
                let sessions = loadScheduledSessions()
                if let newest = sessions.first(where: { $0.id == s.id }) {
                    scheduledSession = newest
                    selectedDuration = newest.durationMinutes
                }
            }

            // Fresh UI for a scheduled session
            if let s = scheduledSession, s.status == .scheduled {
                sessionTimer.isFocusing = false
                sessionTimer.sessionComplete = false
                sessionTimer.rewardEarned = false
                sessionTimer.timeRemaining = selectedDuration * 60
            }

            // Apply snapshot only if it matches this session
            if let snap = loadCurrentSessionSnapshot() {
                let matches = (snap.scheduledSessionID != nil && snap.scheduledSessionID == scheduledSession?.id)

                if snap.isActive && matches {
                    sessionTimer.restoreFromEndDate(snap.endDate)
                } else if snap.didFail && matches {
                    sessionTimer.isFocusing = false
                    sessionTimer.sessionComplete = true
                    sessionTimer.rewardEarned = false
                    sessionTimer.timeRemaining = 0
                    saveCurrentSessionSnapshot(nil)
                } else if snap.didSucceed && matches {
                    sessionTimer.isFocusing = false
                    sessionTimer.sessionComplete = true
                    sessionTimer.rewardEarned = true
                    sessionTimer.timeRemaining = 0
                    saveCurrentSessionSnapshot(nil)
                }
            }
        }

        .onChange(of: sessionTimer.sessionComplete) { _, done in
            if !done { return }

            if let s = scheduledSession {
                var sessions = loadScheduledSessions()
                if let idx = sessions.firstIndex(where: { $0.id == s.id }) {
                    sessions[idx].status = sessionTimer.rewardEarned ? .completed : .failed
                    saveScheduledSessions(sessions)
                    scheduledSession = sessions[idx]
                }
            }

            // Clear snapshot after end
            saveCurrentSessionSnapshot(nil)
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let hrs = seconds / 3600
        let mins = (seconds % 3600) / 60
        let secs = seconds % 60
        if hrs > 0 { return String(format: "%d:%02d:%02d", hrs, mins, secs) }
        return String(format: "%02d:%02d", mins, secs)
    }
}

#Preview {
    FocusSessionView()
        .environmentObject(FocusSessionTimer())
}
