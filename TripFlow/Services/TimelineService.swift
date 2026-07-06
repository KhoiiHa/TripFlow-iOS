//
//  TimelineService.swift
//  TripFlow
//
//  Created by Vu Minh Khoi Ha on 06.07.26.
//

import Foundation

struct Timeline {
    let days: [TimelineDay]
    let unscheduledStops: [Stop]

    var orderedStops: [Stop] {
        days.flatMap(\.stops) + unscheduledStops
    }
}

struct TimelineDay: Identifiable {
    let date: Date
    let stops: [Stop]

    var id: Date {
        date
    }
}

struct TimelineService {
    func makeTimeline(for trip: Trip, calendar: Calendar = .current) -> Timeline {
        let scheduledStops = trip.stops
            .compactMap { stop -> (day: Date, stop: Stop)? in
                guard let scheduledDate = stop.scheduledDate else {
                    return nil
                }

                return (calendar.startOfDay(for: scheduledDate), stop)
            }
            .sorted { sortScheduledStops($0.stop, $1.stop) }

        let days = Dictionary(grouping: scheduledStops, by: \.day)
            .map { TimelineDay(date: $0.key, stops: $0.value.map(\.stop)) }
        .sorted { $0.date < $1.date }

        let unscheduledStops = trip.stops
            .filter { $0.scheduledDate == nil }
            .sorted { $0.orderIndex < $1.orderIndex }

        return Timeline(days: days, unscheduledStops: unscheduledStops)
    }

    func sortedStops(for trip: Trip, calendar: Calendar = .current) -> [Stop] {
        makeTimeline(for: trip, calendar: calendar).orderedStops
    }

    private func sortScheduledStops(_ first: Stop, _ second: Stop) -> Bool {
        guard let firstDate = first.scheduledDate else {
            return false
        }

        guard let secondDate = second.scheduledDate else {
            return true
        }

        if firstDate == secondDate {
            return first.orderIndex < second.orderIndex
        }

        return firstDate < secondDate
    }
}
