//
//  FocusSessionView.swift
//  Focastra
//
//  Created by Isaac Law on 2025-11-03.
//

import SwiftUI

//WIP
struct FocusSessionView: View {
    @Environment(\.scenePhase) private var scenePhase //from mentor
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sessionTimer: FocusSessionTimer

    // Keep only the configuration passed in
    @State private var selectedDuration: Int // minutes

    // Optional scheduled session info passed in by the caller
    @State private var scheduledSession: ScheduledSession? = nil

    init(durationMinutes: Int = 30, scheduled: ScheduledSession? = nil) {
        _selectedDuration = State(initialValue: durationMinutes)
        _scheduledSession = State(initialValue: scheduled)
    }

    var body: some View {
        //AppLogo()
        
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
                
                // Single button: start and stay here
                Button {
                    if !sessionTimer.isFocusing {
                        if let sched = scheduledSession, (sched.status == .completed || sched.status == .failed) {
                            return
                        }
                        // Enforce: can only start on or before scheduled time, and only if date is today
                        if let sched = scheduledSession {
                            let now = Date()
                            let cal = Calendar.current
                            // If not today or now is after scheduled time, do not start
                            if !cal.isDate(sched.scheduledDate, inSameDayAs: now) || now > sched.scheduledDate {
                                // Simply return without starting; caller can navigate back to scheduling if desired
                                return
                            }
                        }
                        sessionTimer.start(durationMinutes: selectedDuration)
                        // Persist a snapshot so we can restore if the app restarts
                        let snapshot = makeCurrentSessionSnapshot(durationMinutes: selectedDuration, start: Date())
                        saveCurrentSessionSnapshot(snapshot)
                    }
                } label: {
                    Text(sessionTimer.isFocusing ? "Focusing..." : "Start Focus Session")
                        .font(.custom("Impact", size: 40))
                        .padding()
                        .background(.focastra, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                        .opacity(sessionTimer.isFocusing ? 0.6 : 1.0)
                }
                .disabled(sessionTimer.isFocusing || ((scheduledSession?.status == .completed) || (scheduledSession?.status == .failed)))
                
                // Encouragement text when focusing
                if sessionTimer.isFocusing {
                    Text("Stay focused for \(selectedDuration) minutes!")
                        .font(.headline)
                        .padding(.top, 20)
                }
                
                // Session complete message
                if sessionTimer.sessionComplete {
                    Text(sessionTimer.rewardEarned ? "🎉 Session Complete! Reward Earned!" : "⛔ Session Ended Early. No reward.")
                        .font(.headline)
                        .padding(.top, 20)
                }
                
                Spacer()
            }
            .padding()
            .onAppear {
                // If not focusing, ensure displayed time reflects the chosen duration
                if !sessionTimer.isFocusing {
                    sessionTimer.timeRemaining = selectedDuration * 60
                }
            }
            // Auto-return home when the session finishes or ends early
            .onChange(of: sessionTimer.sessionComplete) { _, isComplete in
                if isComplete {
                    // If this view was launched for a specific scheduled session, mark its result
                    if let sched = scheduledSession {
                        var sessions = loadScheduledSessions()
                        if let idx = sessions.firstIndex(where: { $0.id == sched.id }) {
                            if sessionTimer.rewardEarned {
                                sessions[idx].status = .completed
                            } else {
                                sessions[idx].status = .failed
                            }
                            saveScheduledSessions(sessions)
                        }
                    }
                    // removed dismiss() as requested
                }
            }
            // Keep accuracy across scene changes by recomputing from the current time
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:
                    sessionTimer.resyncIfNeeded()
                    // Reconcile persisted snapshot on becoming active (may auto-complete if finished while away)
                    var persisted = loadCurrentSessionSnapshot()
                    handleScenePhaseForSnapshot(
                        snapshot: &persisted,
                        onActive: {
                            // No-op: timer is already resynced above
                        },
                        onSuccess: {
                            // Session finished while away; ensure timer reflects completion
                            if sessionTimer.isFocusing {
                                sessionTimer.completeSession()
                            }
                        },
                        onFailure: {
                            // Not used here; failure handled on background
                        },
                        now: Date()
                    )
                    print("✅ App became active again")
                case .inactive:
                    print("⚠️ App became inactive (e.g. Control Center opened)")
                case .background:
                    // Persist immediate failure when moving to background during an active session
                    var persisted = loadCurrentSessionSnapshot()
                    markBackgroundFailureForSnapshot(
                        snapshot: &persisted,
                        onFailure: {
                            // Timer will be ended below
                        }
                    )
                    print("🚫 App moved to background (user left the app!)")
                    if sessionTimer.isFocusing {
                        sessionTimer.endEarly()
                    }
                    // If associated with a scheduled session, mark it failed on background
                    if let sched = scheduledSession {
                        var sessions = loadScheduledSessions()
                        if let idx = sessions.firstIndex(where: { $0.id == sched.id }) {
                            sessions[idx].status = .failed
                            saveScheduledSessions(sessions)
                        }
                    }
                @unknown default:
                    print("Unknown scene phase")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(edges: .bottom)
        .background(Gradient(colors: gradientColors))
    }

    func formatTime(_ seconds: Int) -> String {
        let hrs = seconds / 3600
        let mins = (seconds % 3600) / 60
        let secs = seconds % 60
        
        if hrs > 0 {
            // Show hours if needed (e.g. 1:05:09)
            return String(format: "%d:%02d:%02d", hrs, mins, secs)
        } else {
            // Otherwise, just show minutes and seconds (e.g. 25:43)
            return String(format: "%02d:%02d", mins, secs)
        }
    }
}

#Preview {
    FocusSessionView()
        .environmentObject(FocusSessionTimer()) // Preview support
}

