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
    @Published var timeRemaining: Int = 0      // seconds
    @Published var rewardEarned: Bool = false
    @Published var sessionComplete: Bool = false
    @Published var selectedDurationMinutes: Int = 30

    private var endDate: Date? = nil
    private var timer: Timer? = nil

    func start(durationMinutes: Int) {
        // Avoid double-start
        guard !isFocusing, timer == nil else { return }

        selectedDurationMinutes = durationMinutes
        isFocusing = true
        sessionComplete = false
        rewardEarned = false

        let duration = TimeInterval(durationMinutes * 60)
        endDate = Date().addingTimeInterval(duration)
        timeRemaining = Int(duration)

        startInternalTimer()
    }

    // ✅ Used when we reopen the app / come back and want to continue the same timer
    func restoreFromEndDate(_ savedEndDate: Date) {
        guard !isFocusing else { return }

        endDate = savedEndDate

        let remaining = Int(savedEndDate.timeIntervalSinceNow.rounded(.down))
        if remaining > 0 {
            isFocusing = true
            sessionComplete = false
            rewardEarned = false
            timeRemaining = remaining
            startInternalTimer()
        } else {
            // already finished
            completeSession()
        }
    }

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

        // Keeps timer working smoothly with UI
        RunLoop.main.add(timer!, forMode: .common)
    }

    // ✅ failure / early end
    func endEarly() {
        timer?.invalidate()
        timer = nil

        isFocusing = false
        sessionComplete = true
        rewardEarned = false

        endDate = nil
        timeRemaining = 0
    }

    // ✅ success
    func completeSession() {
        isFocusing = false
        sessionComplete = true
        rewardEarned = true

        endDate = nil
        timeRemaining = 0
    }

    // ✅ when app becomes active: recalc remaining time using wall clock
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
}
