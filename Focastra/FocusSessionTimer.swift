//
//  FocusSessionTimer.swift
//  Focastra
//
//  Created by Isaac Law on 2025-12-16.
//

import Foundation
import Combine

final class FocusSessionTimer: ObservableObject {

    @Published var isFocusing: Bool = false
    @Published var timeRemaining: Int = 0 // seconds
    @Published var rewardEarned: Bool = false
    @Published var sessionComplete: Bool = false
    @Published var selectedDurationMinutes: Int = 30

    private var endDate: Date? = nil
    private var timer: Timer? = nil

    // ✅ Persistence keys (simple + beginner friendly)
    private let endDateKey = "focastra_endDate"
    private let wasFocusingKey = "focastra_wasFocusing"

    // MARK: - Start

    func start(durationMinutes: Int) {
        guard !isFocusing, timer == nil else { return }

        selectedDurationMinutes = durationMinutes
        isFocusing = true
        sessionComplete = false
        rewardEarned = false

        let durationSeconds = durationMinutes * 60
        let newEndDate = Date().addingTimeInterval(TimeInterval(durationSeconds))

        endDate = newEndDate
        timeRemaining = durationSeconds

        // ✅ Persist immediately (so force-close still leaves evidence)
        saveEndDateToUserDefaults(newEndDate)

        startInternalTimer()
    }

    // MARK: - Restore

    func restoreFromEndDate(_ savedEndDate: Date) {
        guard !isFocusing else { return }

        endDate = savedEndDate
        saveEndDateToUserDefaults(savedEndDate)

        let remaining = Int(savedEndDate.timeIntervalSinceNow.rounded(.down))
        if remaining > 0 {
            isFocusing = true
            sessionComplete = false
            rewardEarned = false
            timeRemaining = remaining
            startInternalTimer()
        } else {
            completeSession()
        }
    }

    // MARK: - Force-close detection

    /// True if we have a saved endDate in the future and the app previously marked "was focusing".
    func hadActiveTimerWhenAppClosed() -> Bool {
        let wasFocusing = UserDefaults.standard.bool(forKey: wasFocusingKey)
        guard wasFocusing else { return false }

        guard let savedEndDate = UserDefaults.standard.object(forKey: endDateKey) as? Date else {
            return false
        }

        return savedEndDate.timeIntervalSinceNow > 0
    }

    func getSavedEndDate() -> Date? {
        return UserDefaults.standard.object(forKey: endDateKey) as? Date
    }

    // MARK: - Internal timer

    private func startInternalTimer() {
        timer?.invalidate()
        timer = nil

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
            guard let self = self, let endDate = self.endDate else {
                t.invalidate()
                self?.timer = nil
                self?.isFocusing = false
                return
            }

            let remaining = Int(endDate.timeIntervalSinceNow.rounded(.down))
            if remaining > 0 {
                self.timeRemaining = remaining
            } else {
                t.invalidate()
                self.timer = nil
                self.completeSession()
            }
        }

        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    // MARK: - Failure / Success

    func endEarly() {
        timer?.invalidate()
        timer = nil

        isFocusing = false
        sessionComplete = true
        rewardEarned = false

        endDate = nil
        timeRemaining = 0

        clearEndDateFromUserDefaults()
    }

    func completeSession() {
        isFocusing = false
        sessionComplete = true
        rewardEarned = true

        endDate = nil
        timeRemaining = 0

        clearEndDateFromUserDefaults()
    }

    // MARK: - Resync

    func resyncIfNeeded() {
        guard isFocusing, let endDate else { return }

        let remaining = Int(endDate.timeIntervalSinceNow.rounded(.down))
        if remaining > 0 {
            timeRemaining = remaining
        } else {
            timer?.invalidate()
            timer = nil
            completeSession()
        }
    }

    // MARK: - UserDefaults helpers

    private func saveEndDateToUserDefaults(_ date: Date) {
        UserDefaults.standard.set(true, forKey: wasFocusingKey)
        UserDefaults.standard.set(date, forKey: endDateKey)
        UserDefaults.standard.synchronize()
    }

    private func clearEndDateFromUserDefaults() {
        UserDefaults.standard.set(false, forKey: wasFocusingKey)
        UserDefaults.standard.removeObject(forKey: endDateKey)
        UserDefaults.standard.synchronize()
    }
}
