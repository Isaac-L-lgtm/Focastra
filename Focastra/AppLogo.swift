//
//  AppLogo.swift
//  Focastra
//
//  Created by Isaac Law on 2025-11-05.
//

import SwiftUI

struct AppLogo: View {
    // Built-in margin so it sits nicely when placed near edges.
    private let builtInTopMargin: CGFloat = 8
    private let builtInLeadingMargin: CGFloat = 8

    var body: some View {
        HStack(spacing: 8) {
            Image("focastra_logo")
                .resizable()
                .scaledToFit()
                .frame(width: 75, height: 75)

            Text("Focastra")
                .font(.custom("Impact", size: 32))
                .foregroundColor(.black) // Change to .white if preferred
                .padding(.leading, -25)
        }
        .padding(.top, builtInTopMargin)
        .padding(.leading, builtInLeadingMargin)
    }
}

#Preview {
    ZStack {
        Color.white.ignoresSafeArea()
        // Preview centered; in app, position with overlay/alignment if needed
        AppLogo()
    }
}
