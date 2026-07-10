//
//  DateDisplayFormatter.swift
//  TripFlow
//
//  Created by Vu Minh Khoi Ha on 10.07.26.
//

import Foundation

enum DateDisplayFormatter {
    private static let locale = Locale(identifier: "de_DE")

    static func date(_ date: Date, calendar: Calendar = .current) -> String {
        string(from: date, calendar: calendar, dateFormat: "d. MMMM yyyy")
    }

    static func time(_ date: Date, calendar: Calendar = .current) -> String {
        string(from: date, calendar: calendar, dateFormat: "HH:mm")
    }

    static func dateTime(_ date: Date, calendar: Calendar = .current) -> String {
        string(from: date, calendar: calendar, dateFormat: "d. MMMM yyyy, HH:mm")
    }

    static func weekdayDate(_ date: Date, calendar: Calendar = .current) -> String {
        string(from: date, calendar: calendar, dateFormat: "EEEE, d. MMMM yyyy")
    }

    private static func string(from date: Date, calendar: Calendar, dateFormat: String) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = dateFormat

        return formatter.string(from: date)
    }
}
