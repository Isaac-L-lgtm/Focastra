//
//  FeaturesPage.swift
//  Focastra
//
//  Created by Isaac Law on 2025-10-30.
//

import SwiftUI

struct FeaturesPage: View {
    var body: some View {
        VStack {
            Text("Features")
                .font(.title)
                .font(.custom("Arial Black", size: 20))
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.bottom)
            
            
            FeatureCard(iconName: "calendar", description: "Plan your day by setting when and how long you want to focus.")
            
            FeatureCard(iconName: "lock.circle.fill", description: "Keep the app open or lock your phone to stay productive.")
            
            FeatureCard(iconName: "flame.circle.fill", description: "Complete sessions to earn stars and build your focus streak.")
            
            FeatureCard(iconName: "wifi.slash", description: "Stay focused anywhere — even without Wi-Fi or data.")
            
            FeatureCard(iconName: "person.2.circle.fill", description: "Compare your focus streaks and achievements with friends for extra motivation.")
        }
        .padding()
    }
}


#Preview {
    FeaturesPage()
}

