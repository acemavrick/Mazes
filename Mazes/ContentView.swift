//
//  ContentView.swift
//  Mazes
//
//  Created by acemavrick on 5/15/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        #if os(iOS)
        Frontend_iOS()
        #elseif os(macOS)
        Frontend_macOS()
        #endif
    }
}

#Preview {
    ContentView()
}
