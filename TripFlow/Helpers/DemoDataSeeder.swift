//
//  DemoDataSeeder.swift
//  TripFlow
//
//  Created by Codex on 12.07.26.
//

#if DEBUG
import Foundation
import SwiftData

enum DemoDataSeeder {
    static let launchArgument = "-tripflowDemoData"

    static func seedIfRequested(in container: ModelContainer, processInfo: ProcessInfo = .processInfo) {
        guard processInfo.arguments.contains(launchArgument) else {
            return
        }

        let context = ModelContext(container)

        do {
            let existingTrips = try context.fetch(FetchDescriptor<Trip>())
            for trip in existingTrips {
                context.delete(trip)
            }

            let trip = Trip(
                title: "Berlin Sommertrip",
                startDate: date(year: 2026, month: 7, day: 15, hour: 9, minute: 0),
                endDate: date(year: 2026, month: 7, day: 18, hour: 18, minute: 0)
            )

            let hotelStop = Stop(
                title: "Hotel Check-in",
                locationName: "Alexanderplatz 1, Berlin",
                scheduledDate: date(year: 2026, month: 7, day: 15, hour: 14, minute: 30),
                latitude: 52.5219,
                longitude: 13.4132,
                orderIndex: 0,
                trip: trip
            )

            let flightStop = Stop(
                title: "Rueckflug LH2034",
                locationName: "BER Terminal 1",
                scheduledDate: date(year: 2026, month: 7, day: 18, hour: 9, minute: 5),
                latitude: 52.3667,
                longitude: 13.5033,
                orderIndex: 1,
                trip: trip
            )

            let document = TravelDocument(
                title: "Hotelbuchung",
                documentType: "Hotel",
                fileName: "hotel.pdf",
                extractedText: """
                Hotel Check-in 15.07.2026 ab 14:30 Uhr
                Adresse: Alexanderplatz 1, Berlin
                Reservierung: H12345
                """,
                trip: trip
            )

            trip.stops = [hotelStop, flightStop]
            trip.documents = [document]

            context.insert(trip)
            context.insert(hotelStop)
            context.insert(flightStop)
            context.insert(document)

            try context.save()
        } catch {
            assertionFailure("Could not seed demo data: \(error)")
        }
    }

    private static func date(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current

        return calendar.date(
            from: DateComponents(
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute
            )
        ) ?? Date()
    }
}
#endif
