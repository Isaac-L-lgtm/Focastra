//
//  FocusSessionCore.swift
//  Focastra
//
//  Created by Isaac Law on 2025-11-20.
//

import Foundation

// MARK: - Models

// A simple scheduled session model you can store.
// - id: unique identifier
// - scheduledDate: when it should start
// - durationMinutes: how long it should run
// - status: scheduled/completed/failed (no in-progress tracking here)
struct ScheduledSession: Identifiable, Codable, Equatable {
    enum Status: String, Codable {
        case scheduled
        case completed
        case failed
    }

    let id: UUID
    var scheduledDate: Date
    var durationMinutes: Int
    var status: Status

    init(id: UUID = UUID(), scheduledDate: Date, durationMinutes: Int, status: Status = .scheduled) {
        self.id = id
        self.scheduledDate = scheduledDate
        self.durationMinutes = durationMinutes
        self.status = status
    }
}

// Snapshot of a currently running session for persistence.
// This lets you restore remaining time and outcome after relaunch.
// Keep it minimal and separate from your existing timer class.
struct PersistedCurrentSession: Codable, Equatable {
    var isActive: Bool
    var endDate: Date
    var didSucceed: Bool
    var didFail: Bool
}

// MARK: - Persistence

private let kScheduledSessionsKey = "Focastra.scheduledSessions"
private let kCurrentSessionKey = "Focastra.currentSession"

func loadScheduledSessions() -> [ScheduledSession] {
    let defaults = UserDefaults.standard
    guard let data = defaults.data(forKey: kScheduledSessionsKey) else { return [] }
    do {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([ScheduledSession].self, from: data)
    } catch {
        return []
    }
}

func saveScheduledSessions(_ sessions: [ScheduledSession]) {
    let defaults = UserDefaults.standard
    do {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(sessions)
        defaults.set(data, forKey: kScheduledSessionsKey)
    } catch {
        // Ignore errors for simplicity
    }
}

func loadCurrentSessionSnapshot() -> PersistedCurrentSession? {
    let defaults = UserDefaults.standard
    guard let data = defaults.data(forKey: kCurrentSessionKey) else { return nil }
    do {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(PersistedCurrentSession.self, from: data)
    } catch {
        return nil
    }
}

func saveCurrentSessionSnapshot(_ snapshot: PersistedCurrentSession?) {
    let defaults = UserDefaults.standard
    if let snapshot {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(snapshot)
            defaults.set(data, forKey: kCurrentSessionKey)
        } catch {
            // Ignore write errors
        }
    } else {
        defaults.removeObject(forKey: kCurrentSessionKey)
    }
}

// MARK: - Logic (pure helpers)

// Returns the earliest scheduled session for "today" that is not in the past.
func nextSessionForToday(from sessions: [ScheduledSession], now: Date) -> ScheduledSession? {
    let cal = Calendar.current
    return sessions
        .filter {
            $0.status == .scheduled &&
            cal.isDate($0.scheduledDate, inSameDayAs: now) &&
            now <= $0.scheduledDate
        }
        .sorted { $0.scheduledDate < $1.scheduledDate }
        .first
}

// Remove sessions that were scheduled earlier today but never started (past now).
func removeMissedSessionsForToday(_ sessions: inout [ScheduledSession], now: Date) {
    let cal = Calendar.current
    sessions.removeAll { s in
        s.status == .scheduled &&
        cal.isDate(s.scheduledDate, inSameDayAs: now) &&
        s.scheduledDate < now
    }
}

// Call this when the user actually presses "Start" and you begin your existing timer.
// It returns a snapshot you can save for restoration later.
func makeCurrentSessionSnapshot(durationMinutes: Int, start: Date) -> PersistedCurrentSession {
    let end = start.addingTimeInterval(TimeInterval(durationMinutes * 60))
    return PersistedCurrentSession(isActive: true, endDate: end, didSucceed: false, didFail: false)
}

// Recompute remaining seconds from a snapshot and "now" (pure helper).
func remainingSeconds(from snapshot: PersistedCurrentSession, now: Date) -> Int {
    max(0, Int(snapshot.endDate.timeIntervalSince(now).rounded(.down)))
}

// Handle scene phase transitions for success/failure with your existing timer:
// - On active: recompute remaining; if zero, success.
// - On background: if still active, failure immediately.
// Note: You still use your FocusSessionTimer to maintain seconds; this only updates persistence flags.
func handleScenePhaseForSnapshot(
    snapshot: inout PersistedCurrentSession?,
    onActive: () -> Void,
    onSuccess: () -> Void,
    onFailure: () -> Void,
    now: Date
) {
    guard var s = snapshot else { return }

    if !s.isActive {
        // Already completed, nothing to do
        return
    }

    let remaining = remainingSeconds(from: s, now: now)
    if remaining == 0 {
        // Success while app was away
        s.isActive = false
        s.didSucceed = true
        s.didFail = false
        snapshot = s
        saveCurrentSessionSnapshot(s)
        onSuccess()
    } else {
        // Still active; let your UI/timer continue
        snapshot = s
        saveCurrentSessionSnapshot(s)
        onActive()
    }
}

// Mark failure when app moves to background during an active session.
func markBackgroundFailureForSnapshot(
    snapshot: inout PersistedCurrentSession?,
    onFailure: () -> Void
) {
    guard var s = snapshot, s.isActive else { return }
    s.isActive = false
    s.didSucceed = false
    s.didFail = true
    snapshot = s
    saveCurrentSessionSnapshot(s)
    onFailure()
}
