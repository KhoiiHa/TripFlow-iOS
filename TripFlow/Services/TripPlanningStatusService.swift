//
//  TripPlanningStatusService.swift
//  TripFlow
//
//  Created by Vu Minh Khoi Ha on 08.07.26.
//

import Foundation

enum TripPlanningStatus {
    case empty
    case planning
    case ready

    var title: String {
        switch self {
        case .empty:
            return "Empty"
        case .planning:
            return "Planning"
        case .ready:
            return "Ready"
        }
    }
}

struct TripPlanningSummary {
    let stopCountText: String
    let documentCountText: String
    let dateRangeText: String
    let status: TripPlanningStatus
}

struct TripPlanningStatusService {
    func summary(for trip: Trip) -> TripPlanningSummary {
        TripPlanningSummary(
            stopCountText: countText(count: trip.stops.count, singular: "Stop", plural: "Stops"),
            documentCountText: countText(count: trip.documents.count, singular: "Unterlage", plural: "Unterlagen"),
            dateRangeText: dateRangeText(for: trip),
            status: status(for: trip)
        )
    }

    func status(for trip: Trip) -> TripPlanningStatus {
        if trip.stops.isEmpty {
            return .empty
        }

        if trip.documents.isEmpty {
            return .planning
        }

        return .ready
    }

    private func countText(count: Int, singular: String, plural: String) -> String {
        count == 1 ? "1 \(singular)" : "\(count) \(plural)"
    }

    private func dateRangeText(for trip: Trip) -> String {
        switch (trip.startDate, trip.endDate) {
        case let (startDate?, endDate?):
            return "\(format(date: startDate)) - \(format(date: endDate))"
        case let (startDate?, nil):
            return "Start: \(format(date: startDate))"
        case let (nil, endDate?):
            return "Ende: \(format(date: endDate))"
        case (nil, nil):
            return "Zeitraum offen"
        }
    }

    private func format(date: Date) -> String {
        DateDisplayFormatter.date(date)
    }
}
