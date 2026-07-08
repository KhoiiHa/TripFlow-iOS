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
    let suggestedStopTitle: String?
    let suggestedLocationName: String?
    let flightNumber: String?
    let trainNumber: String?
    let reservationNumber: String?
}

struct TravelDocumentParserService {
    func parse(_ text: String, calendar: Calendar = .current) -> TravelDocumentParseResult {
        let date = parseDate(in: text)
        let time = parseTime(in: text)
        let scheduledDate = makeDate(from: date, time: time, calendar: calendar)
        let suggestedStopTitle = parseSuggestedStopTitle(in: text)
        let suggestedLocationName = parseSuggestedLocationName(in: text)
        let flightNumber = parseFlightNumber(in: text)
        let trainNumber = parseTrainNumber(in: text)
        let reservationNumber = parseReservationNumber(in: text)

        return TravelDocumentParseResult(
            date: date,
            time: time,
            scheduledDate: scheduledDate,
            suggestedStopTitle: suggestedStopTitle,
            suggestedLocationName: suggestedLocationName,
            flightNumber: flightNumber,
            trainNumber: trainNumber,
            reservationNumber: reservationNumber
        )
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

    private func parseSuggestedStopTitle(in text: String) -> String? {
        let normalizedText = text.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        )

        if normalizedText.contains("hotel")
            || normalizedText.contains("check-in")
            || normalizedText.contains("checkin")
            || normalizedText.contains("unterkunft") {
            return "Hotel Check-in"
        }

        if normalizedText.contains("flug")
            || normalizedText.contains("flight")
            || normalizedText.contains("boarding")
            || normalizedText.contains("gate") {
            return "Flug"
        }

        if normalizedText.contains("bahn")
            || normalizedText.contains("zug")
            || normalizedText.contains("train")
            || normalizedText.contains("ice") {
            return "Bahnfahrt"
        }

        if normalizedText.contains("restaurant")
            || normalizedText.contains("reservierung")
            || normalizedText.contains("reservation") {
            return "Reservierung"
        }

        return nil
    }

    private func parseSuggestedLocationName(in text: String) -> String? {
        let locationLabels = [
            "adresse",
            "address",
            "ort",
            "location",
            "flughafen",
            "airport",
            "bahnhof",
            "station",
            "hotel"
        ]

        for line in text.split(whereSeparator: \.isNewline) {
            let trimmedLine = String(line).trimmingCharacters(in: .whitespacesAndNewlines)

            guard let separatorIndex = trimmedLine.firstIndex(where: { $0 == ":" || $0 == "-" }) else {
                continue
            }

            let rawLabel = String(trimmedLine[..<separatorIndex])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            let valueStartIndex = trimmedLine.index(after: separatorIndex)
            let value = String(trimmedLine[valueStartIndex...])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if locationLabels.contains(rawLabel), value.isEmpty == false {
                return value
            }
        }

        return nil
    }

    private func parseFlightNumber(in text: String) -> String? {
        let regex = #/(?<flight>[A-Z]{2}\s?\d{2,4})/#

        for line in text.split(whereSeparator: \.isNewline) {
            let uppercasedLine = String(line).uppercased()

            guard uppercasedLine.contains("FLUG")
                    || uppercasedLine.contains("FLIGHT")
                    || uppercasedLine.contains("BOARDING") else {
                continue
            }

            if let match = uppercasedLine.firstMatch(of: regex) {
                return String(match.flight).replacingOccurrences(of: " ", with: "")
            }
        }

        return nil
    }

    private func parseTrainNumber(in text: String) -> String? {
        let regex = #/(?<train>(?:ICE|IC|EC|RE|RB|S)\s?\d{1,4})/#

        for line in text.split(whereSeparator: \.isNewline) {
            let uppercasedLine = String(line).uppercased()

            guard uppercasedLine.contains("BAHN")
                    || uppercasedLine.contains("ZUG")
                    || uppercasedLine.contains("TRAIN")
                    || uppercasedLine.contains("ICE")
                    || uppercasedLine.contains("IC")
                    || uppercasedLine.contains("EC") else {
                continue
            }

            if let match = uppercasedLine.firstMatch(of: regex) {
                return String(match.train).replacingOccurrences(of: " ", with: "")
            }
        }

        return nil
    }

    private func parseReservationNumber(in text: String) -> String? {
        let reservationLabels = [
            "reservierung",
            "reservation",
            "buchungsnummer",
            "booking",
            "confirmation"
        ]

        for line in text.split(whereSeparator: \.isNewline) {
            let trimmedLine = String(line).trimmingCharacters(in: .whitespacesAndNewlines)

            guard let separatorIndex = trimmedLine.firstIndex(where: { $0 == ":" || $0 == "-" }) else {
                continue
            }

            let rawLabel = String(trimmedLine[..<separatorIndex])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            let valueStartIndex = trimmedLine.index(after: separatorIndex)
            let value = String(trimmedLine[valueStartIndex...])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if reservationLabels.contains(where: { rawLabel.contains($0) }),
               let reservationNumber = firstReferenceToken(in: value) {
                return reservationNumber
            }
        }

        return nil
    }

    private func firstReferenceToken(in text: String) -> String? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = trimmedText.split(whereSeparator: { character in
            character.isWhitespace || character == "," || character == ";" || character == "/"
        }).first

        guard let token, token.isEmpty == false else {
            return nil
        }

        return String(token)
    }
}
