//
//  StatsPage.swift
//  Focastra
//
//  Created by Isaac Law on 2025-11-11.
//

import SwiftUI

//WIP
struct StatsPage: View {
    var body: some View {
        ZStack {
            AppLogo()
            
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(edges: .bottom)
        .background(Gradient(colors: gradientColors))
    }
}

#Preview {
    StatsPage()
}
