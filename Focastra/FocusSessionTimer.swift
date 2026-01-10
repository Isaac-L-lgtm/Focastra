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

    func start(durationMinutes: Int) {
        // Avoid double-starts
        guard !isFocusing, timer == nil else { return }
        selectedDurationMinutes = durationMinutes
        isFocusing = true
        sessionComplete = false
        rewardEarned = false

        let duration = TimeInterval(durationMinutes * 60)
        endDate = Date().addingTimeInterval(duration)
        timeRemaining = Int(duration)

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
        // Ensure the timer continues during UI interactions
        RunLoop.main.add(timer!, forMode: .common)
    }

    func endEarly() {
        timer?.invalidate()
        timer = nil
        isFocusing = false
        sessionComplete = true
        rewardEarned = false
        endDate = nil
        timeRemaining = 0
    }

    func completeSession() {
        isFocusing = false
        sessionComplete = true
        rewardEarned = true
        endDate = nil
        timeRemaining = 0
    }

    // Call when the app becomes active to re-sync against wall clock
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
