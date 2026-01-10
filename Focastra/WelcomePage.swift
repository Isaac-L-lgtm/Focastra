//
//  WelcomePage.swift
//  OnboardingFlow
//
//  Created by Isaac Law on 2025-10-15.
//

import SwiftUI

struct WelcomePage: View {
    var body: some View {
        VStack {
            ZStack {
                RoundedRectangle(cornerRadius: 30)
                    .frame(width: 150, height: 150)
                    .foregroundStyle(.focastra)
                
                Image(systemName: "star.fill")
                    .font(.system(size: 70))
                    .foregroundStyle(.yellow)
                    .rotationEffect(.degrees(354))
                
            }
            
            //Welcome (text is white)
            Text("Welcome to Focastra")
                .font(.custom("Impact", size: 43))
                .padding(.top)
                .padding(.bottom, 9)
                .foregroundColor(.white)
            
            //Tagline (text is white)
            Text("Your goals.")
                .font(.custom("Arial Black", size: 20))
                .foregroundColor(.white)
            Text("Your focus.")
                .font(.custom("Arial Black", size: 20))
                .foregroundColor(.white)
            Text("Your achievement.")
                .font(.custom("Arial Black", size: 20))
                .foregroundColor(.white)
        }
        .padding()
    }
}

#Preview {
    WelcomePage()
}
