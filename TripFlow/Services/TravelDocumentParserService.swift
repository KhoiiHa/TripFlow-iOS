//
//  TravelDocumentParserService.swift
//  TripFlow
//
//  Created by Vu Minh Khoi Ha on 07.07.26.
//

import Foundation

struct TravelDocumentParsedDate: Equatable {
    let day: Int
    let month: Int
    let year: Int
}

struct TravelDocumentParsedTime: Equatable {
    let hour: Int
    let minute: Int
}

struct TravelDocumentParseResult: Equatable {
    let date: TravelDocumentParsedDate?
    let time: TravelDocumentParsedTime?
    let scheduledDate: Date?
}

struct TravelDocumentParserService {
    func parse(_ text: String, calendar: Calendar = .current) -> TravelDocumentParseResult {
        let date = parseDate(in: text)
        let time = parseTime(in: text)
        let scheduledDate = makeDate(from: date, time: time, calendar: calendar)

        return TravelDocumentParseResult(date: date, time: time, scheduledDate: scheduledDate)
    }

    private func parseDate(in text: String) -> TravelDocumentParsedDate? {
        let regex = #/(?<day>\d{1,2})[./-](?<month>\d{1,2})[./-](?<year>\d{4}|\d{2})/#

        guard let match = text.firstMatch(of: regex),
              let day = Int(match.day),
              let month = Int(match.month),
              let rawYear = Int(match.year) else {
            return nil
        }

        let year = rawYear < 100 ? 2000 + rawYear : rawYear

        guard (1...31).contains(day), (1...12).contains(month) else {
            return nil
        }

        return TravelDocumentParsedDate(day: day, month: month, year: year)
    }

    private func parseTime(in text: String) -> TravelDocumentParsedTime? {
        let regex = #/(?:^|[^\d./-])(?<hour>\d{1,2})[:.](?<minute>\d{2})(?:[^\d./-]|$)/#

        guard let match = text.firstMatch(of: regex),
              let hour = Int(match.hour),
              let minute = Int(match.minute),
              (0...23).contains(hour),
              (0...59).contains(minute) else {
            return nil
        }

        return TravelDocumentParsedTime(hour: hour, minute: minute)
    }

    private func makeDate(
        from date: TravelDocumentParsedDate?,
        time: TravelDocumentParsedTime?,
        calendar: Calendar
    ) -> Date? {
        guard let date, let time else {
            return nil
        }

        return DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: date.year,
            month: date.month,
            day: date.day,
            hour: time.hour,
            minute: time.minute
        ).date
    }
}
