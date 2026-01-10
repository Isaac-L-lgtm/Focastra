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

    // Own the dates here and pass them down via bindings/values
    @State private var selectedDates: Set<DateComponents> = []
    @State private var goToSelectDates = false
    @State private var goToSuggested = false

    // store today's planned session start time
    @State private var todaySessionStart: Date? = nil
    // store today's planned session duration (in minutes)
    @State private var todaySessionDurationMinutes: Int? = nil

    // Navigation from the "Now" button directly into FocusSessionView or times
    @State private var goToTimesFromNow = false
    @State private var goToFocusSession = false

    // Temporary dates
    @State private var tempDatesForNow: Set<DateComponents> = []
    
    // Keep a notion of "now" so the UI can update when time passes
    @State private var now: Date = Date()
    private let nowTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    // Scheduled sessions storage and computed next session for today
    @State private var scheduledSessions: [ScheduledSession] = []
    @State private var nextTodaySession: ScheduledSession? = nil

    private func refreshSessions() {
        var sessions = loadScheduledSessions()
        removeMissedSessionsForToday(&sessions, now: Date())
        saveScheduledSessions(sessions)
        scheduledSessions = sessions
        
        let now = Date()
        let cal = Calendar.current
        // Consider only today's sessions that are not completed/failed and whose time is >= now
        let todaysAvailable = sessions.filter { s in
            (s.status != .completed && s.status != .failed) && cal.isDate(s.scheduledDate, inSameDayAs: now) && s.scheduledDate >= now
        }
        // Pick the earliest such session if any
        nextTodaySession = todaysAvailable.sorted(by: { $0.scheduledDate < $1.scheduledDate }).first
    }

    private var hasValidTodaySession: Bool {
        guard let start = todaySessionStart else { return false }
        let cal = Calendar.current
        return cal.isDateInToday(start)
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) { // anchors the nav bar at the bottom
                // User + Icon Button
                Button(action: {
                    // Switch to the Stats tab (tag 2)
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
                    
                    // "Current Streak" Label
                    Text("Current Streak")
                        .font(.custom("Impact", size: 40))
                        .foregroundColor(.streak)
                        .padding(.bottom, 10)
                    
                    // "Now" Label
                    Text("Now")
                        .font(.custom("Arial Black", size: 25))
                        .foregroundColor(.black)
                        .padding(.leading, -190)
                    
                    // "Now" Button
                    Button(action: {
                        refreshSessions()
                        if hasValidTodaySession {
                            // Use the same source of truth as the label; navigate directly
                            if let upcoming = nextTodaySession {
                                todaySessionStart = upcoming.scheduledDate
                                todaySessionDurationMinutes = upcoming.durationMinutes
                            }
                            goToFocusSession = true
                        } else {
                            // No session today -> take user to SelectDatesView
                            let cal = Calendar.current
                            let today = Date()
                            let comps = cal.dateComponents([.year, .month, .day], from: today)
                            selectedDates = [comps]
                            goToSelectDates = true
                        }
                    }) {
                        // Toggle content based on whether we have a valid session today
                        if hasValidTodaySession, let start = todaySessionStart {
                            HStack {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 75))
                                    .padding(.horizontal, -5)
                                Spacer(minLength: 25)
                                let durationText: String = {
                                    if let mins = todaySessionDurationMinutes {
                                        if mins % 60 == 0 {
                                            return "\(mins / 60)h"
                                        } else {
                                            return "\(mins)min"
                                        }
                                    } else {
                                        return "30min"
                                    }
                                }()
                                Text("Focus Session at \(timeFormatter.string(from: start)) · \(durationText)")
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
                    
                    //"Suggested" Button
                    Button(action: {
                        print("Suggest Focus Session tapped")
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

                    //Bottom "+ New Focus Session" Button
                    Button(action: {
                        // Reset any date selections for a fresh start
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
                    //make bool var true
                    EmptyView()
                }
                
                
                NavigationLink(
                    destination: SuggestedSessionPage(),
                    isActive: $goToSuggested
                ) {
                    EmptyView()
                }
                
                AppLogo()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.top, 0)
                    .padding(.leading, -20)
            }
            .ignoresSafeArea(edges: .bottom)
            .background(Gradient(colors: gradientColors))
            .onAppear {
                refreshSessions()
            }
            .onReceive(nowTimer) { _ in
                // Periodically refresh to roll over sessions as time passes
                refreshSessions()
                now = Date()
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $goToFocusSession) {
                FocusSessionView(
                    durationMinutes: todaySessionDurationMinutes ?? 30,
                    scheduled: nextTodaySession
                )
            }
            .navigationDestination(isPresented: $goToTimesFromNow) {
                SelectTimesView(
                    selectedDates: tempDatesForNow,
                    selectedStartTime: $todaySessionStart,
                    selectedDurationMinutes: $todaySessionDurationMinutes,
                    goToSelectDatesActive: .constant(false)
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
    // Provide a constant for previews
    HomePage(tabSelection: .constant(0))
}

