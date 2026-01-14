//
//  FocusSessionView.swift
//  Focastra
//
//  Created by Isaac Law on 2025-11-03.
//

import SwiftUI

struct FocusSessionView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sessionTimer: FocusSessionTimer

    @State private var selectedDuration: Int
    @State private var scheduledSession: ScheduledSession? = nil

    // If false, Start button is never shown (used for failure screen after force-close)
    private let allowStarting: Bool

    init(durationMinutes: Int = 30,
         scheduled: ScheduledSession? = nil,
         allowStarting: Bool = true) {
        _selectedDuration = State(initialValue: durationMinutes)
        _scheduledSession = State(initialValue: scheduled)
        self.allowStarting = allowStarting
    }

    private var canShowStartButton: Bool {
        if !allowStarting { return false }
        if sessionTimer.isFocusing { return false }
        if sessionTimer.sessionComplete { return false }
        if let s = scheduledSession { return s.status == .scheduled }
        return true
    }

    // ✅ Show only ONE "Back to Home" button (no duplicates)
    private var shouldShowBackToHomeButton: Bool {
        // If this view is opened as a failure screen (fullScreenCover), show button
        if !allowStarting { return true }

        // If a normal session finished (success or fail), show button
        if sessionTimer.sessionComplete { return true }

        return false
    }

    var body: some View {
        ZStack {
            VStack(spacing: 16) {

                Text("Focus Session")
                    .font(.custom("Impact", size: 60))
                    .fontWeight(.bold)
                    .padding(.top, 90)
                    .padding(.bottom, 40)

                Text(formatTime(sessionTimer.timeRemaining))
                    .font(.custom("Impact", size: 60))
                    .fontWeight(.bold)
                    .padding(.bottom, 20)

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
                        .padding(.top, 8)
                }

                if sessionTimer.sessionComplete {
                    Text(sessionTimer.rewardEarned
                         ? "✅ Session Complete! Reward Earned!"
                         : "⛔ Session Failed.\nNo reward.")
                        .font(.headline)
                        .padding(.top, 8)
                        .multilineTextAlignment(.center)
                }

                if shouldShowBackToHomeButton {
                    Button("Back to Home") {
                        dismiss()
                    }
                    .font(.headline)
                    .padding(.top, 12)
                }

                Spacer()
            }
            .padding()
        }
        .ignoresSafeArea(edges: .bottom)
        .background(Gradient(colors: gradientColors))

        .onAppear {
            // Reload latest scheduled session status
            if let s = scheduledSession {
                let sessions = loadScheduledSessions()
                if let newest = sessions.first(where: { $0.id == s.id }) {
                    scheduledSession = newest
                    selectedDuration = newest.durationMinutes
                }
            }

            // Default timer display for scheduled session
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

            // Apply snapshot ONLY if it matches this scheduled session
            if let snap = loadCurrentSessionSnapshot() {
                let matchesThisSession =
                    (snap.scheduledSessionID != nil &&
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
