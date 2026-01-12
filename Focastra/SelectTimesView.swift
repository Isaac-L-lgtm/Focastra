//
//  SelectTimesView.swift
//  Focastra
//
//  Created by Isaac Law on 2025-11-10.
//

import SwiftUI

//WIP
struct SelectTimesView: View {
    // Receive the chosen dates as a value
    let selectedDates: Set<DateComponents>

    // Write the chosen start time back to HomePage
    @Binding var selectedStartTime: Date?
    // Write the chosen duration (in minutes) back to HomePage
    @Binding var selectedDurationMinutes: Int?
    // Control whether SelectDatesView is active (provided by HomePage)
    @Binding var goToSelectDatesActive: Bool
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTime = Date()
    @State private var durationTime = "30 mins"

    private let durationOptions: [(label: String, minutes: Int)] = [
        ("1 mins", 1), //remove
        ("30 mins", 30),
        ("1 hour", 60),
        ("1 hour 30 mins", 90),
        ("2 hours", 120),
        ("2 hours 30 mins", 150),
        ("3 hours", 180),
        ("3 hours 30 mins", 210),
        ("4 hours", 240),
        ("4 hours 30 mins", 270),
        ("5 hours", 300),
        ("5 hours 30 mins", 330),
        ("6 hours", 360)
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 25) {
                HStack {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 35))
                    Text("Choose your focus start time and duration")
                        .font(.custom("Impact", size: 25))
                        .multilineTextAlignment(.leading)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.top, 5) //40
                
                Spacer()
                
                DatePicker("Start", selection: $selectedTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .background()
                
                Spacer()
                
                Text("Duration")
                    .font(.custom("Impact", size: 25))
                    .foregroundStyle(.white)
                Picker("Duration", selection: $durationTime) {
                    ForEach(durationOptions.map(\.label), id: \.self) {
                        Text($0)
                    }
                }
                .background(Color.cyan)
                .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    // Save the chosen start time back to Home
                    selectedStartTime = selectedTime

                    // Save the chosen duration (label -> minutes)
                    let minutes = durationOptions.first(where: { $0.label == durationTime })?.minutes ?? 30
                    selectedDurationMinutes = minutes

                    // Explicitly deactivate the SelectDatesView link so the stack collapses back to Home.
                    goToSelectDatesActive = false

                    // Also dismiss this view (if it was pushed directly from Home via the "Now" path).
                    dismiss()
                }) {
                    Text("Done")
                        .font(.custom("Impact", size: 25))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 40)
                        .background(.focastra, in: Capsule())
                        .foregroundColor(.black)
                }
                .padding(.bottom, 80) //40
            }
            .padding()
        }
        .ignoresSafeArea(edges: .bottom)
        .background(Gradient(colors: gradientColors))
    }
}

#Preview {
    @Previewable @State var previewStart: Date? = nil
    @Previewable @State var previewDuration: Int? = nil
    @Previewable @State var previewActive = true
    SelectTimesView(selectedDates: [], selectedStartTime: $previewStart, selectedDurationMinutes: $previewDuration, goToSelectDatesActive: $previewActive)
}

