//
//  TripFlowApp.swift
//  TripFlow
//
//  Created by Vu Minh Khoi Ha on 05.07.26.
//

import SwiftUI
import SwiftData

@main
struct TripFlowApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Trip.self,
            Stop.self,
            TravelDocument.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        #if DEBUG
        DemoDataSeeder.seedIfRequested(in: sharedModelContainer)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
