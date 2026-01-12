//
//  SelectDatesView.swift
//  Focastra
//
//  Created by Isaac Law on 2025-11-10.
//

import SwiftUI

//WIP
struct SelectDatesView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Binding from HomePage
    @Binding var selectedDates: Set<DateComponents>
    // New: pass the chosen start time back to HomePage
    @Binding var selectedStartTime: Date?
    // New: pass the chosen duration (minutes) back to HomePage
    @Binding var selectedDurationMinutes: Int?
    // New: control the activation of this SelectDatesView from HomePage
    @Binding var goToSelectDatesActive: Bool
    
    @State private var goToTimes = false

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 25) {
                HStack {
                    Image(systemName: "calendar")
                        .font(.system(size: 35))
                    Text("Select when you want to have your focus sessions")
                        .font(.custom("Impact", size: 25))
                        .multilineTextAlignment(.leading)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.top, 5)
                
                MultiDatePicker(
                    "Dates Available",
                    selection: $selectedDates,
                    in: Date()... //disables past days
                )
                    .background(Color.cyan)
                    .foregroundStyle(.white)
                
                Spacer()
                
                HStack(spacing: 20) {
                    Button(action: {
                        guard !selectedDates.isEmpty else {
                            print("No dates selected")
                            return
                        }
                        goToTimes = true
                    }) {
                        Text("Next")
                            .font(.custom("Impact", size: 25))
                            .padding(.vertical, 10)
                            .padding(.horizontal, 40)
                            .background(.focastra, in: Capsule())
                            .foregroundColor(.black)
                    }
                    .padding(.bottom, 80)
                    .disabled(selectedDates.isEmpty)
                    .opacity(selectedDates.isEmpty ? 0.6 : 1.0)
                }
            }
            .padding()
        }
        .navigationDestination(isPresented: $goToTimes) {
            SelectTimesView(
                selectedDates: selectedDates,
                selectedStartTime: $selectedStartTime,
                selectedDurationMinutes: $selectedDurationMinutes,
                goToSelectDatesActive: $goToSelectDatesActive
            )
        }
        .onDisappear {
            if !goToTimes {
                selectedDates.removeAll()
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .background(Gradient(colors: gradientColors))
    }
}

#Preview {
    @Previewable @State var previewDates: Set<DateComponents> = []
    @Previewable @State var previewStart: Date? = nil
    @Previewable @State var previewDuration: Int? = nil
    @Previewable @State var previewActive = true
    SelectDatesView(selectedDates: $previewDates, selectedStartTime: $previewStart, selectedDurationMinutes: $previewDuration, goToSelectDatesActive: $previewActive)
}
