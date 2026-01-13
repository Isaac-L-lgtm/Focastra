//
//  HomePage.swift
//  Focastra
//
//  Created by Isaac Law on 2025-11-04.
//

import SwiftUI
import Combine

struct HomePage: View {

    // Binding to the TabView selection in ContentView
    @Binding var tabSelection: Int

    // Needed so we can show "Focusing..." on the Home button
    @EnvironmentObject private var sessionTimer: FocusSessionTimer

    // Date picker selections
    @State private var selectedDates: Set<DateComponents> = []
    @State private var goToSelectDates = false
    @State private var goToSuggested = false

    // These are just helpers for the FocusSessionView navigation
    @State private var todaySessionStart: Date? = nil
    @State private var todaySessionDurationMinutes: Int? = nil

    // Navigation
    @State private var goToFocusSession = false

    // Keep a notion of "now" so the UI updates when time passes (every second)
    @State private var now: Date = Date()
    private let nowTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // Scheduled sessions storage + next session for today
    @State private var scheduledSessions: [ScheduledSession] = []
    @State private var nextTodaySession: ScheduledSession? = nil

    private func refreshSessions() {
        var sessions = loadScheduledSessions()

        // Remove sessions that already passed today without starting
        removeMissedSessionsForToday(&sessions, now: Date())

        // Save the cleaned list back
        saveScheduledSessions(sessions)

        // Store for UI
        scheduledSessions = sessions

        // Get the earliest pending session for today
        nextTodaySession = nextSessionForToday(from: sessions, now: Date())

        // Keep helpers in sync (used when navigating)
        todaySessionStart = nextTodaySession?.scheduledDate
        todaySessionDurationMinutes = nextTodaySession?.durationMinutes
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {

                // User + Icon Button (go to stats tab)
                Button(action: {
                    tabSelection = 2
                }) {
                    VStack(spacing: 1) {
                        Image(systemName: "star.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 35, height: 35)
                            .foregroundColor(.yellow)
                            .shadow(radius: 3)

                        Text("User")
                            .font(.custom("Impact", size: 24))
                            .foregroundColor(.black)
                    }
                    .padding(.trailing, 10)
                    .padding(.top, 30)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

                VStack(spacing: 20) {

                    // Streak Section
                    ZStack {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 65))
                            .foregroundColor(.black)
                            .padding(.top, 50)

                        Text("0")
                            .font(.custom("Impact", size: 70))
                            .foregroundColor(.streak)
                            .padding(.top, 90)
                    }

                    Text("Current Streak")
                        .font(.custom("Impact", size: 40))
                        .foregroundColor(.streak)
                        .padding(.bottom, 10)

                    // "Now" Label
                    Text("Now")
                        .font(.custom("Arial Black", size: 25))
                        .foregroundColor(.black)
                        .padding(.leading, -190)

                    // ✅ NOW Button (rules)
                    Button(action: {
                        refreshSessions()

                        // If timer is running -> go to FocusSessionView
                        if sessionTimer.isFocusing {
                            goToFocusSession = true
                            return
                        }

                        // If next session today exists -> go to FocusSessionView
                        if nextTodaySession != nil {
                            goToFocusSession = true
                        } else {
                            // Otherwise -> SelectDatesView (to create one)
                            let cal = Calendar.current
                            let comps = cal.dateComponents([.year, .month, .day], from: Date())
                            selectedDates = [comps]
                            goToSelectDates = true
                        }
                    }) {

                        // ✅ Button Text (rules)
                        if sessionTimer.isFocusing {
                            HStack {
                                Image(systemName: "timer")
                                    .font(.system(size: 75))
                                    .padding(.horizontal, -5)

                                Spacer(minLength: 25)

                                Text("Focusing...")
                                    .font(.custom("Impact", size: 30))
                            }
                            .padding()
                            .foregroundColor(.white)
                            .background(Color(.black).opacity(0.49), in: RoundedRectangle(cornerRadius: 15))

                        } else if let upcoming = nextTodaySession {
                            HStack {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 75))
                                    .padding(.horizontal, -5)

                                Spacer(minLength: 25)

                                let mins = upcoming.durationMinutes
                                let durationText: String = {
                                    if mins % 60 == 0 { return "\(mins / 60)h" }
                                    return "\(mins)min"
                                }()

                                Text("Focus Session at \(timeFormatter.string(from: upcoming.scheduledDate)) · \(durationText)")
                                    .font(.custom("Impact", size: 28))
                            }
                            .padding()
                            .foregroundColor(.white)
                            .background(Color(.black).opacity(0.49), in: RoundedRectangle(cornerRadius: 15))

                        } else {
                            HStack {
                                Image(systemName: "bed.double.fill")
                                    .font(.system(size: 75))
                                    .padding(.horizontal, -5)

                                Spacer(minLength: 25)

                                Text("No Focus Session Today")
                                    .font(.custom("Impact", size: 30))
                            }
                            .padding()
                            .foregroundColor(.white)
                            .background(Color(.black).opacity(0.49), in: RoundedRectangle(cornerRadius: 15))
                        }
                    }
                    .padding(.horizontal, 30)

                    Spacer(minLength: 20)

                    // Suggested Button
                    Button(action: {
                        goToSuggested = true
                    }) {
                        HStack {
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 75))
                                .padding(.horizontal, -5)

                            Spacer(minLength: 25)

                            Text("Add Suggested Session")
                                .font(.custom("Impact", size: 30))
                        }
                        .padding()
                        .foregroundColor(.white)
                        .background(Color(.black).opacity(0.49), in: RoundedRectangle(cornerRadius: 15))
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, -40)

                    // Bottom "+ New Focus Session" Button
                    Button(action: {
                        selectedDates.removeAll()
                        goToSelectDates = true
                    }) {
                        Text("+ New Focus Session")
                            .font(.custom("Impact", size: 22))
                            .padding(.vertical, 10)
                            .padding(.horizontal, 25)
                            .background(.focastra, in: Capsule())
                            .foregroundColor(.black)
                            .padding(.trailing, 10)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(.top, 20)

                    Spacer(minLength: 100)
                }

                // Hidden programmatic navigation links
                NavigationLink(
                    destination: SelectDatesView(
                        selectedDates: $selectedDates,
                        selectedStartTime: $todaySessionStart,
                        selectedDurationMinutes: $todaySessionDurationMinutes,
                        goToSelectDatesActive: $goToSelectDates
                    ),
                    isActive: $goToSelectDates
                ) {
                    EmptyView()
                }

                NavigationLink(destination: SuggestedSessionPage(), isActive: $goToSuggested) {
                    EmptyView()
                }

                AppLogo()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.top, 0)
                    .padding(.leading, -20)
            }
            .ignoresSafeArea(edges: .bottom)
            .background(Gradient(colors: gradientColors))
            .onAppear { refreshSessions() }
            .onReceive(nowTimer) { _ in
                now = Date()
                refreshSessions()
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $goToFocusSession) {
                FocusSessionView(
                    durationMinutes: nextTodaySession?.durationMinutes ?? 30,
                    scheduled: nextTodaySession
                )
            }
        }
    }

    // tells time for the "Now" button
    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }
}

#Preview {
    HomePage(tabSelection: .constant(0))
        .environmentObject(FocusSessionTimer())
}
