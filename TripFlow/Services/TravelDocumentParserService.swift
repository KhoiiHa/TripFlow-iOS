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
    let departureLocationName: String?
    let arrivalLocationName: String?
    let departureScheduledDate: Date?
    let arrivalScheduledDate: Date?
    let scheduledDateFormatIsAmbiguous: Bool
    let departureDateFormatIsAmbiguous: Bool
    let arrivalDateFormatIsAmbiguous: Bool
    let arrivalDateWasAdjustedToFollowingDay: Bool
    let flightNumber: String?
    let trainNumber: String?
    let reservationNumber: String?
}

struct TravelDocumentParserService {
    func parse(_ text: String, calendar: Calendar = .current) -> TravelDocumentParseResult {
        let fallbackDateValue = parseDate(in: text, calendar: calendar)
        let fallbackDate = fallbackDateValue?.date
        let fallbackTime = parseTime(in: text)
        let fallbackSchedule = makeSchedule(
            date: fallbackDate,
            time: fallbackTime,
            calendar: calendar,
            dateFormatIsAmbiguous: fallbackDateValue?.formatIsAmbiguous ?? false
        )
        let departureLocationName = parseLocationName(
            in: text,
            labels: ["von", "from", "start", "origin", "abfahrtsort", "departure airport", "departure station"]
        )
        let arrivalLocationName = parseLocationName(
            in: text,
            labels: ["nach", "to", "ziel", "destination", "ankunftsort", "arrival airport", "arrival station"]
        )
        let genericLocationName = parseLocationName(
            in: text,
            labels: ["adresse", "address", "ort", "location", "flughafen", "airport", "bahnhof", "station", "hotel"]
        )
        let suggestedLocationName = arrivalLocationName
            ?? genericLocationName
            ?? departureLocationName
        let departureScheduleResult = parseLabeledSchedule(
            in: text,
            labels: ["abfahrt", "departure", "abflug", "depart"],
            fallbackDate: fallbackDateValue,
            calendar: calendar
        )
        let departureSchedule: ParsedSchedule?

        switch departureScheduleResult {
        case .schedule(let schedule):
            departureSchedule = schedule
        case .absent:
            departureSchedule = departureLocationName == nil ? nil : fallbackSchedule
        case .invalid:
            departureSchedule = nil
        }

        let arrivalScheduleResult = parseLabeledSchedule(
            in: text,
            labels: ["ankunft", "arrival", "landung", "arrive"],
            fallbackDate: fallbackDateValue,
            calendar: calendar
        )
        let arrivalSchedule = adjustedArrivalSchedule(
            arrivalScheduleResult.parsedSchedule,
            after: departureSchedule,
            calendar: calendar
        )
        let hasCompleteRoute = departureLocationName != nil && arrivalLocationName != nil
        let suggestedSchedule = hasCompleteRoute
            ? arrivalSchedule
            : (arrivalSchedule ?? departureSchedule ?? fallbackSchedule)
        let flightNumber = parseFlightNumber(in: text)
        let trainNumber = parseTrainNumber(in: text)
        let suggestedStopTitle = parseSuggestedStopTitle(
            in: text,
            flightNumber: flightNumber,
            trainNumber: trainNumber
        )
        let reservationNumber = parseReservationNumber(in: text)

        return TravelDocumentParseResult(
            date: suggestedSchedule?.date ?? fallbackDate,
            time: suggestedSchedule?.time ?? fallbackTime,
            scheduledDate: suggestedSchedule?.scheduledDate,
            suggestedStopTitle: suggestedStopTitle,
            suggestedLocationName: suggestedLocationName,
            departureLocationName: departureLocationName,
            arrivalLocationName: arrivalLocationName,
            departureScheduledDate: departureSchedule?.scheduledDate,
            arrivalScheduledDate: arrivalSchedule?.scheduledDate,
            scheduledDateFormatIsAmbiguous: suggestedSchedule?.dateFormatIsAmbiguous ?? false,
            departureDateFormatIsAmbiguous: departureSchedule?.dateFormatIsAmbiguous ?? false,
            arrivalDateFormatIsAmbiguous: arrivalSchedule?.dateFormatIsAmbiguous ?? false,
            arrivalDateWasAdjustedToFollowingDay: arrivalSchedule?.wasAdjustedToFollowingDay ?? false,
            flightNumber: flightNumber,
            trainNumber: trainNumber,
            reservationNumber: reservationNumber
        )
    }

    private func parseDate(in text: String, calendar: Calendar) -> ParsedDateValue? {
        let isoRegex = #/(?:^|[^\d])(?<year>\d{4})-(?<month>\d{2})-(?<day>\d{2})(?:[^\d]|$)/#

        if let match = text.firstMatch(of: isoRegex) {
            guard let day = Int(match.day),
                  let month = Int(match.month),
                  let year = Int(match.year) else {
                return nil
            }

            guard let date = validatedDate(day: day, month: month, year: year, calendar: calendar) else {
                return nil
            }

            return ParsedDateValue(date: date, formatIsAmbiguous: false)
        }

        let regex = #/(?:^|[^\d])(?<day>\d{1,2})(?<firstSeparator>[./-])(?<month>\d{1,2})(?<secondSeparator>[./-])(?<year>\d{4}|\d{2})(?:[^\d]|$)/#

        guard let match = text.firstMatch(of: regex),
              let day = Int(match.day),
              let month = Int(match.month),
              let rawYear = Int(match.year) else {
            return nil
        }

        let year = rawYear < 100 ? 2000 + rawYear : rawYear

        guard let date = validatedDate(day: day, month: month, year: year, calendar: calendar) else {
            return nil
        }

        let formatIsAmbiguous = match.firstSeparator == "/"
            && match.secondSeparator == "/"
            && day <= 12
            && month <= 12

        return ParsedDateValue(date: date, formatIsAmbiguous: formatIsAmbiguous)
    }

    private func validatedDate(
        day: Int,
        month: Int,
        year: Int,
        calendar: Calendar
    ) -> TravelDocumentParsedDate? {
        guard (1...31).contains(day), (1...12).contains(month) else {
            return nil
        }

        let parsedDate = TravelDocumentParsedDate(day: day, month: month, year: year)
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: 12
        )

        guard let date = components.date else {
            return nil
        }

        let validatedComponents = calendar.dateComponents([.day, .month, .year], from: date)

        guard validatedComponents.day == day,
              validatedComponents.month == month,
              validatedComponents.year == year else {
            return nil
        }

        return parsedDate
    }

    private func containsDateCandidate(in text: String) -> Bool {
        let isoRegex = #/(?:^|[^\d])\d{4}-\d{2}-\d{2}(?:[^\d]|$)/#
        let dayFirstRegex = #/(?:^|[^\d])\d{1,2}[./-]\d{1,2}[./-](?:\d{4}|\d{2})(?:[^\d]|$)/#

        return text.firstMatch(of: isoRegex) != nil
            || text.firstMatch(of: dayFirstRegex) != nil
    }

    private func parseTime(in text: String) -> TravelDocumentParsedTime? {
        let normalizedText = text.uppercased()
        let twelveHourRegex = #/(?:^|[^\d./-])(?<hour>\d{1,2})[:.](?<minute>\d{2})[ \t]*(?<meridiem>AM|PM)\b/#

        if let match = normalizedText.firstMatch(of: twelveHourRegex) {
            guard let hour = Int(match.hour),
                  let minute = Int(match.minute),
                  (1...12).contains(hour),
                  (0...59).contains(minute) else {
                return nil
            }

            let normalizedHour = hour % 12 + (match.meridiem == "PM" ? 12 : 0)
            return TravelDocumentParsedTime(hour: normalizedHour, minute: minute)
        }

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

    private func makeSchedule(
        date: TravelDocumentParsedDate?,
        time: TravelDocumentParsedTime?,
        calendar: Calendar,
        dateWasInferred: Bool = false,
        dateFormatIsAmbiguous: Bool = false
    ) -> ParsedSchedule? {
        guard let date,
              let time,
              let scheduledDate = makeDate(from: date, time: time, calendar: calendar) else {
            return nil
        }

        return ParsedSchedule(
            date: date,
            time: time,
            scheduledDate: scheduledDate,
            dateWasInferred: dateWasInferred,
            dateFormatIsAmbiguous: dateFormatIsAmbiguous,
            wasAdjustedToFollowingDay: false
        )
    }

    private func parseLabeledSchedule(
        in text: String,
        labels: [String],
        fallbackDate: ParsedDateValue?,
        calendar: Calendar
    ) -> LabeledScheduleParseResult {
        var foundInvalidValue = false

        for line in text.split(whereSeparator: \.isNewline) {
            guard let value = labeledValue(
                in: String(line),
                labels: labels,
                allowsLabelSuffix: true
            ) else {
                continue
            }

            let parsedDate = parseDate(in: value, calendar: calendar)

            if parsedDate == nil, containsDateCandidate(in: value) {
                foundInvalidValue = true
                continue
            }

            let dateValue = parsedDate ?? fallbackDate
            let time = parseTime(in: value)

            if let schedule = makeSchedule(
                date: dateValue?.date,
                time: time,
                calendar: calendar,
                dateWasInferred: parsedDate == nil,
                dateFormatIsAmbiguous: dateValue?.formatIsAmbiguous ?? false
            ) {
                return .schedule(schedule)
            }

            foundInvalidValue = true
        }

        return foundInvalidValue ? .invalid : .absent
    }

    private func adjustedArrivalSchedule(
        _ arrivalSchedule: ParsedSchedule?,
        after departureSchedule: ParsedSchedule?,
        calendar: Calendar
    ) -> ParsedSchedule? {
        guard let arrivalSchedule,
              arrivalSchedule.dateWasInferred,
              let departureSchedule,
              arrivalSchedule.scheduledDate <= departureSchedule.scheduledDate,
              let nextDay = calendar.date(byAdding: .day, value: 1, to: arrivalSchedule.scheduledDate) else {
            return arrivalSchedule
        }

        let components = calendar.dateComponents([.day, .month, .year], from: nextDay)

        guard let day = components.day,
              let month = components.month,
              let year = components.year else {
            return arrivalSchedule
        }

        return ParsedSchedule(
            date: TravelDocumentParsedDate(day: day, month: month, year: year),
            time: arrivalSchedule.time,
            scheduledDate: nextDay,
            dateWasInferred: true,
            dateFormatIsAmbiguous: arrivalSchedule.dateFormatIsAmbiguous,
            wasAdjustedToFollowingDay: true
        )
    }

    private func parseSuggestedStopTitle(
        in text: String,
        flightNumber: String?,
        trainNumber: String?
    ) -> String? {
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
            if let flightNumber {
                return "Flug \(flightNumber)"
            }

            return "Flug"
        }

        if normalizedText.contains("bahn")
            || normalizedText.contains("zug")
            || normalizedText.contains("train")
            || normalizedText.contains("ice") {
            if let trainNumber {
                return "Bahnfahrt \(trainNumber)"
            }

            return "Bahnfahrt"
        }

        if normalizedText.contains("restaurant")
            || normalizedText.contains("reservierung")
            || normalizedText.contains("reservation") {
            return "Reservierung"
        }

        return nil
    }

    private func parseLocationName(
        in text: String,
        labels: [String],
        allowsLabelSuffix: Bool = false
    ) -> String? {
        for line in text.split(whereSeparator: \.isNewline) {
            guard let value = labeledValue(
                in: String(line),
                labels: labels,
                allowsLabelSuffix: allowsLabelSuffix
            ), value.contains(where: \.isLetter) else {
                continue
            }

            return value
        }

        return nil
    }

    private func labeledValue(
        in line: String,
        labels: [String],
        allowsLabelSuffix: Bool
    ) -> String? {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let separatorIndex = trimmedLine.firstIndex(where: { $0 == ":" || $0 == "-" }) else {
            return nil
        }

        let rawLabel = String(trimmedLine[..<separatorIndex])
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let matchesLabel = labels.contains { label in
            rawLabel == label
                || (allowsLabelSuffix && rawLabel.hasPrefix("\(label) "))
        }

        guard matchesLabel else {
            return nil
        }

        let valueStartIndex = trimmedLine.index(after: separatorIndex)
        let value = String(trimmedLine[valueStartIndex...])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return value.isEmpty ? nil : value
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

private struct ParsedSchedule {
    let date: TravelDocumentParsedDate
    let time: TravelDocumentParsedTime
    let scheduledDate: Date
    let dateWasInferred: Bool
    let dateFormatIsAmbiguous: Bool
    let wasAdjustedToFollowingDay: Bool
}

private struct ParsedDateValue {
    let date: TravelDocumentParsedDate
    let formatIsAmbiguous: Bool
}

private enum LabeledScheduleParseResult {
    case absent
    case invalid
    case schedule(ParsedSchedule)

    var parsedSchedule: ParsedSchedule? {
        guard case .schedule(let schedule) = self else {
            return nil
        }

        return schedule
    }
}
