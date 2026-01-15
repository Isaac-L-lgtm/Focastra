//
//  StatsPage.swift
//  Focastra
//
//  Created by Isaac Law on 2025-11-11.
//


import SwiftUI
import Combine

struct StatsPage: View {
    @State private var sessions: [ScheduledSession] = []
    @State private var now: Date = Date()
    private let nowTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private func refresh() {
        sessions = loadScheduledSessions()
    }

    // MARK: - Stats

    private var finishedSessions: [ScheduledSession] {
        sessions
            .filter { $0.status != .scheduled }
            .sorted { $0.scheduledDate < $1.scheduledDate }
    }

    private var completedCount: Int {
        sessions.filter { $0.status == .completed }.count
    }

    private var failedCount: Int {
        sessions.filter { $0.status == .failed }.count
    }

    private var totalFinishedCount: Int {
        completedCount + failedCount
    }

    private var successRateText: String {
        let total = totalFinishedCount
        if total == 0 { return "0%" }
        let rate = (Double(completedCount) / Double(total)) * 100.0
        return "\(Int(rate.rounded()))%"
    }

    private var totalFocusMinutes: Int {
        sessions
            .filter { $0.status == .completed }
            .reduce(0) { $0 + $1.durationMinutes }
    }

    private var totalFocusTimeText: String {
        let mins = totalFocusMinutes
        if mins < 60 { return "\(mins) min" }
        let hrs = mins / 60
        let rem = mins % 60
        return rem == 0 ? "\(hrs) hr" : "\(hrs) hr \(rem) min"
    }

    private var currentStreak: Int {
        var count = 0
        for s in finishedSessions.reversed() {
            if s.status == .failed { return 0 }
            if s.status == .completed { count += 1 }
        }
        return count
    }

    private var bestStreak: Int {
        var best = 0
        var running = 0

        for s in finishedSessions {
            if s.status == .completed {
                running += 1
                best = max(best, running)
            } else if s.status == .failed {
                running = 0
            }
        }
        return best
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 16) {
                HStack {
                    Text("Stats")
                        .font(.custom("Impact", size: 55))
                        .foregroundColor(.black)
                    Spacer()
                }
                .padding(.top, 90)
                .padding(.horizontal, 25)

                VStack(spacing: 14) {
                    HStack(spacing: 14) {
                        statCard(title: "Current Streak", value: "\(currentStreak)", icon: "flame.fill")
                        statCard(title: "Best Streak", value: "\(bestStreak)", icon: "trophy.fill")
                    }

                    HStack(spacing: 14) {
                        statCard(title: "Finished Sessions", value: "\(totalFinishedCount)", icon: "list.bullet.rectangle.fill")
                        statCard(title: "Success Rate", value: successRateText, icon: "chart.bar.fill")
                    }

                    HStack(spacing: 14) {
                        statCard(title: "Completed", value: "\(completedCount)", icon: "checkmark.circle.fill")
                        statCard(title: "Failed", value: "\(failedCount)", icon: "xmark.circle.fill")
                    }

                    statCardWide(title: "Total Focus Time", value: totalFocusTimeText, icon: "clock.fill")
                }
                .padding(.horizontal, 25)

                Spacer()

                AppLogo()
                    .padding(.leading, -20)
                    .padding(.bottom, 40)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .background(Gradient(colors: gradientColors))
        .onAppear { refresh() }
        .onReceive(nowTimer) { _ in
            now = Date()
            refresh()
        }
    }

    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(.black)
                Spacer()
            }

            Text(value)
                .font(.custom("Impact", size: 42))
                .foregroundColor(.black)

            Text(title)
                .font(.custom("Impact", size: 18))
                .foregroundColor(.black.opacity(0.7))
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(Color.black.opacity(0.15), in: RoundedRectangle(cornerRadius: 18))
    }

    private func statCardWide(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 26))
                .foregroundColor(.black)

            VStack(alignment: .leading, spacing: 6) {
                Text(value)
                    .font(.custom("Impact", size: 34))
                    .foregroundColor(.black)

                Text(title)
                    .font(.custom("Impact", size: 18))
                    .foregroundColor(.black.opacity(0.7))
            }

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 90)
        .background(Color.black.opacity(0.15), in: RoundedRectangle(cornerRadius: 18))
    }
}

#Preview {
    StatsPage()
}
