//
//  ContentView.swift
//  TripFlow
//
//  Created by Vu Minh Khoi Ha on 05.07.26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TripListView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Trip.self, Stop.self, TravelDocument.self], inMemory: true)
}
