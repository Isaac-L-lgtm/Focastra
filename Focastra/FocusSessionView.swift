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

    // Start button is only allowed if this session is still scheduled and nothing is already finished
    private var canStartThisSession: Bool {
        if sessionTimer.isFocusing { return false }
        if sessionTimer.sessionComplete { return false }

        // If it’s a scheduled session, only allow start if status is still .scheduled
        if let s = scheduledSession {
            return s.status == .scheduled
        }

        // If no scheduled session was passed, allow start (manual mode)
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

                // ✅ Start button (hidden if completed/failed already)
                if canStartThisSession {
                    Button {
                        // Safety checks
                        if sessionTimer.isFocusing { return }
                        if let sched = scheduledSession, (sched.status == .completed || sched.status == .failed) { return }

                        // ✅ Start allowed only if:
                        // - date is today
                        // - time is coming up (now <= scheduled time)
                        if let sched = scheduledSession {
                            let now = Date()
                            let cal = Calendar.current
                            if !cal.isDate(sched.scheduledDate, inSameDayAs: now) { return }
                            if now > sched.scheduledDate { return }
                        }

                        // Start timer
                        sessionTimer.start(durationMinutes: selectedDuration)

                        // Save snapshot tied to THIS scheduled session
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
            // 1) Refresh scheduled session from storage (so status is accurate)
            if let s = scheduledSession {
                let sessions = loadScheduledSessions()
                if let newest = sessions.first(where: { $0.id == s.id }) {
                    scheduledSession = newest
                    selectedDuration = newest.durationMinutes
                }
            }

            // 2) Reset UI state for a NEW scheduled session (so old failure doesn't block)
            // Only reset if this session is still scheduled
            if let s = scheduledSession, s.status == .scheduled {
                sessionTimer.isFocusing = false
                sessionTimer.sessionComplete = false
                sessionTimer.rewardEarned = false
                sessionTimer.timeRemaining = selectedDuration * 60
            } else if scheduledSession == nil {
                // manual mode
                sessionTimer.timeRemaining = selectedDuration * 60
            }

            // 3) Read snapshot BUT only apply it if it matches this scheduled session
            if let snap = loadCurrentSessionSnapshot() {
                let matchesThisSession = (snap.scheduledSessionID != nil && snap.scheduledSessionID == scheduledSession?.id)

                if snap.isActive && matchesThisSession {
                    // restore timer for this exact session
                    sessionTimer.restoreFromEndDate(snap.endDate)
                } else if snap.didFail && matchesThisSession {
                    // show fail state for this exact session
                    sessionTimer.isFocusing = false
                    sessionTimer.sessionComplete = true
                    sessionTimer.rewardEarned = false
                    sessionTimer.timeRemaining = 0

                    // ✅ Clear snapshot so it doesn't affect future sessions
                    saveCurrentSessionSnapshot(nil)
                } else if snap.didSucceed && matchesThisSession {
                    sessionTimer.isFocusing = false
                    sessionTimer.sessionComplete = true
                    sessionTimer.rewardEarned = true
                    sessionTimer.timeRemaining = 0

                    // ✅ Clear snapshot so it doesn't affect future sessions
                    saveCurrentSessionSnapshot(nil)
                }
                // If snapshot is for a DIFFERENT session, ignore it.
            }
        }

        // When session ends: mark scheduled session completed/failed + clear snapshot (no retries)
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

            // ✅ Always clear snapshot when a session ends (success OR failure)
            // Status is saved in ScheduledSession, so snapshot is no longer needed.
            saveCurrentSessionSnapshot(nil)
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
