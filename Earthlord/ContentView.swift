//
//  ContentView.swift
//  Earthlord
//
//  Created by gong on 2025/12/23.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")

            Text("Developed by Jennyhe")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
                .padding(.top, 20)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
