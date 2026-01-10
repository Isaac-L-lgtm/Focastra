//
//  FeatureCard.swift
//  Focastra
//
//  Created by Isaac Law on 2025-10-30.
//

import SwiftUI


struct FeatureCard: View {
    let iconName: String
    let description: String
    
    var body: some View {
        HStack {
            Image(systemName: iconName)
                .font(.largeTitle)
                .frame(width: 50)
                .padding(.trailing, 10)
            
            Text(description)
            
            Spacer()
        }
        .padding()
        .background(.focastra, in: RoundedRectangle(cornerRadius: 12))
        .foregroundStyle(.white)
    }
}


#Preview {
    FeatureCard(iconName: "calendar",
                description: "Plan your day by setting when and how long you want to focus — from 30 minutes to 6 hours.")
}

