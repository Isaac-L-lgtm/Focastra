//
//  FocusSessionPlanner.swift
//  Focastra
//
//  Created by Isaac Law on 2025-12-16.
//

import Foundation
import Combine


final class FocusSessionPlanner: ObservableObject {
    // Saves dates, times, and duration for each focus session
    @Published var selectedDates: Set<DateComponents> = []
    @Published var startTime: Date? = nil
    @Published var durationLabel: String? = nil
}
