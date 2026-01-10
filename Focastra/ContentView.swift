//
//  ContentView.swift
//  Focastra
//
//  Created by Isaac Law on 2025-10-20.
// FINAL

import SwiftUI
import Combine

//gradient colours for background.
let gradientColors: [Color] = [
    .gradientTop,
    .gradientMiddle,
    .gradientMiddle,
    .gradientBottom
]
//currentPage: 0 and 1 - loading screen

struct ContentView: View {
    @State private var showLoading = true
    @State private var currentPage = 0

    //every 3 seconds, the main run loop auto-advance the loading pages
    let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()
    

    var body: some View {
        ZStack {
            // Gradient background (always visible behind both loading and main content)
            LinearGradient(
                gradient: Gradient(colors: gradientColors),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            if showLoading {
                TabView(selection: $currentPage) {
                    // Page 0: Welcome
                    WelcomePage()
                        .tag(0)
                    // Page 1: Features
                    FeaturesPage()
                        .tag(1)
                }
                .background(Gradient(colors: gradientColors))
                .tabViewStyle(PageTabViewStyle())
                .onReceive(timer) { _ in
                    withAnimation {
                        // Cycle between 0 and 1 (two pages) while loading
                        currentPage = (currentPage + 1) % 2
                    }
                }
                // Animate the loading view when it appears/disappears
                .transition(.opacity .combined(with: .scale))
            }

            // MARK: Home Page (after loading)
            // Main part of app (Home page)
            if !showLoading {
                TabView(selection: $currentPage) {
                    HomePage(tabSelection: $currentPage)
                        .tabItem {
                            Label("Home", systemImage: "star.fill")
                        }
                        .tag(0)
                    
                    CustomizePage()
                        .tabItem {
                            Label("Customize", systemImage: "paintbrush.pointed.fill")
                        }
                        .tag(1)
                    
                    StatsPage()
                        .tabItem {
                            Label("Stats", systemImage: "chart.bar.xaxis")
                        }
                        .tag(2)
                }
                .transition(.opacity) // fade in
            }
        }
        .animation(.easeInOut(duration: 1.0), value: showLoading)
        .onAppear {
            // CHANGE 1 TO 6
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                withAnimation {
                    showLoading = false
                }
                
                var sessions = loadScheduledSessions()
                removeMissedSessionsForToday(&sessions, now: Date())
                saveScheduledSessions(sessions)
            }
        }
    }
}

#Preview {
    ContentView()
        // Provide environment objects so previews match app runtime
        .environmentObject(FocusSessionPlanner())
        .environmentObject(FocusSessionTimer())
}
