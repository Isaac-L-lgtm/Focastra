//
//  FocusSessionPlanner.swift
//  Focastra
//
//  Created by Isaac Law on 2025-12-16.
//

import Foundation
import Combine

//WIP??
final class FocusSessionPlanner: ObservableObject {
    // Days chosen in the calendar
    @Published var selectedDates: Set<DateComponents> = []

    // Optional: store time and duration chosen later
    @Published var startTime: Date? = nil
    @Published var durationLabel: String? = nil
}
