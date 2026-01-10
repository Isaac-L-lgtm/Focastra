//
//  SuggestedSessionPage.swift
//  Focastra
//
//  Created by Isaac Law on 2025-11-20.
//

import SwiftUI

//WIP
struct SuggestedSessionPage: View {
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
    SuggestedSessionPage()
}
