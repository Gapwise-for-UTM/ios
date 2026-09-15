import Foundation

struct ICalendarParser: Sendable {
    static let maximumByteCount = 2 * 1_048_576
    static let maximumEventCount = 2_000

    private static let maximumComponentDepth = 32
    private static let maximumUnfoldedLineByteCount = 65_536

    func parse(_ data: Data) throws -> ICalendarDocument {
        guard data.count <= Self.maximumByteCount else {
            throw TimetableImportError.documentTooLarge(maximumBytes: Self.maximumByteCount)
        }
        guard var text = String(data: data, encoding: .utf8) else {
            throw TimetableImportError.invalidTextEncoding
        }
        guard !text.contains("\0") else {
            throw TimetableImportError.invalidTextEncoding
        }

        if text.hasPrefix("\u{FEFF}") {
            text.removeFirst()
        }

        let lines = try unfold(text)
        var stack: [String] = []
        var sawCalendar = false
        var calendarName: String?
        var productIdentifier: String?
        var events: [ICalendarEvent] = []
        var eventBuilder: EventBuilder?

        for rawLine in lines where !rawLine.isEmpty {
            guard let line = ContentLine(rawLine) else {
                if eventBuilder != nil {
                    eventBuilder?.issues.append(.malformedProperty(Self.possiblePropertyName(in: rawLine)))
                }
                continue
            }

            if line.name == "BEGIN" {
                guard line.parameters.isEmpty, !line.hasMalformedParameters, stack.count < Self.maximumComponentDepth
                else {
                    throw TimetableImportError.malformedCalendar
                }
                let component = line.value.uppercased()
                if component == "VCALENDAR" {
                    guard stack.isEmpty, !sawCalendar else {
                        throw TimetableImportError.malformedCalendar
                    }
                    sawCalendar = true
                } else if stack.isEmpty {
                    throw TimetableImportError.malformedCalendar
                } else if component == "VEVENT" {
                    guard stack == ["VCALENDAR"], eventBuilder == nil else {
                        throw TimetableImportError.malformedCalendar
                    }
                    eventBuilder = EventBuilder()
                }
                stack.append(component)
                continue
            }

            if line.name == "END" {
                guard line.parameters.isEmpty, !line.hasMalformedParameters else {
                    throw TimetableImportError.malformedCalendar
                }
                let component = line.value.uppercased()
                guard stack.last == component else {
                    throw TimetableImportError.malformedCalendar
                }

                if component == "VEVENT", let builder = eventBuilder {
                    guard events.count < Self.maximumEventCount else {
                        throw TimetableImportError.tooManyEvents(maximum: Self.maximumEventCount)
                    }
                    events.append(builder.build())
                    eventBuilder = nil
                }
                stack.removeLast()
                continue
            }

            if stack == ["VCALENDAR"] {
                switch line.name {
                case "X-WR-CALNAME":
                    guard calendarName == nil, !line.hasMalformedParameters else {
                        throw TimetableImportError.malformedCalendar
                    }
                    calendarName = Self.unescapeText(line.value)
                case "PRODID":
                    guard productIdentifier == nil, !line.hasMalformedParameters else {
                        throw TimetableImportError.malformedCalendar
                    }
                    productIdentifier = line.value.trimmingCharacters(in: .whitespacesAndNewlines)
                default: break
                }
            } else if stack == ["VCALENDAR", "VEVENT"] {
                eventBuilder?.consume(line)
            }
        }

        guard sawCalendar else { throw TimetableImportError.missingCalendar }
        guard stack.isEmpty, eventBuilder == nil else { throw TimetableImportError.malformedCalendar }

        return ICalendarDocument(
            calendarName: calendarName?.nilIfEmpty,
            productIdentifier: productIdentifier?.nilIfEmpty,
            events: events
        )
    }

    private func unfold(_ text: String) throws -> [String] {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let physicalLines = normalized.split(separator: "\n", omittingEmptySubsequences: false)
        var lines: [String] = []

        for physicalLine in physicalLines {
            let line = String(physicalLine)
            guard line.utf8.count <= Self.maximumUnfoldedLineByteCount else {
                throw TimetableImportError.malformedCalendar
            }

            if line.first == " " || line.first == "\t" {
                guard let previous = lines.popLast() else {
                    throw TimetableImportError.malformedCalendar
                }
                let unfolded = previous + line.dropFirst()
                guard unfolded.utf8.count <= Self.maximumUnfoldedLineByteCount else {
                    throw TimetableImportError.malformedCalendar
                }
                lines.append(unfolded)
            } else {
                lines.append(line)
            }
        }

        return lines
    }

    fileprivate static func unescapeText(_ value: String) -> String {
        var result = ""
        var isEscaped = false

        for character in value {
            if isEscaped {
                switch character {
                case "n", "N": result.append("\n")
                case "\\": result.append("\\")
                case ",": result.append(",")
                case ";": result.append(";")
                default:
                    result.append("\\")
                    result.append(character)
                }
                isEscaped = false
            } else if character == "\\" {
                isEscaped = true
            } else {
                result.append(character)
            }
        }

        if isEscaped {
            result.append("\\")
        }
        return result
    }

    private static func possiblePropertyName(in line: String) -> String? {
        let candidate = line.prefix { character in
            character.isLetter || character.isNumber || character == "-"
        }.uppercased()
        return candidate.isEmpty ? nil : candidate
    }
}

private struct ContentLine {
    let name: String
    let parameters: [String: String]
    let value: String
    let hasMalformedParameters: Bool

    init?(_ rawLine: String) {
        guard let colon = Self.firstUnquotedColon(in: rawLine) else { return nil }
        let header = String(rawLine[..<colon])
        value = String(rawLine[rawLine.index(after: colon)...])

        let components = Self.splitHeader(header)
        guard let propertyName = components.first?.trimmingCharacters(in: .whitespaces), !propertyName.isEmpty else {
            return nil
        }

        name = propertyName.uppercased()
        var parameters: [String: String] = [:]
        var hasMalformedParameters = false
        for component in components.dropFirst() {
            let pair = component.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard pair.count == 2 else {
                hasMalformedParameters = true
                continue
            }
            let key = pair[0].trimmingCharacters(in: .whitespaces).uppercased()
            guard !key.isEmpty, parameters[key] == nil else {
                hasMalformedParameters = true
                continue
            }
            var parameterValue = pair[1].trimmingCharacters(in: .whitespaces)
            if parameterValue.hasPrefix("\"") && parameterValue.hasSuffix("\"") && parameterValue.count >= 2 {
                parameterValue.removeFirst()
                parameterValue.removeLast()
            }
            parameters[key] = parameterValue
        }
        self.parameters = parameters
        self.hasMalformedParameters = hasMalformedParameters
    }

    private static func firstUnquotedColon(in value: String) -> String.Index? {
        var isQuoted = false
        for index in value.indices {
            let character = value[index]
            if character == "\"" {
                isQuoted.toggle()
            } else if character == ":", !isQuoted {
                return index
            }
        }
        return nil
    }

    private static func splitHeader(_ value: String) -> [String] {
        var components: [String] = []
        var current = ""
        var isQuoted = false

        for character in value {
            if character == "\"" {
                isQuoted.toggle()
                current.append(character)
            } else if character == ";", !isQuoted {
                components.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        components.append(current)
        return components
    }
}

private struct EventBuilder {
    var uid: String?
    var summary: String?
    var location: String?
    var description: String?
    var start: ICalendarTemporalValue?
    var end: ICalendarTemporalValue?
    var recurrenceRule: String?
    var unsupportedRecurrenceProperties: Set<String> = []
    var status: String?
    var issues: [ICalendarEventIssue] = []

    mutating func consume(_ line: ContentLine) {
        guard !line.hasMalformedParameters else {
            issues.append(.malformedProperty(line.name))
            return
        }

        switch line.name {
        case "UID":
            uid = uniqueValue(
                current: uid,
                proposed: line.value.trimmingCharacters(in: .whitespacesAndNewlines),
                propertyName: line.name
            )
        case "SUMMARY":
            summary = uniqueValue(
                current: summary,
                proposed: ICalendarParser.unescapeText(line.value),
                propertyName: line.name
            )
        case "LOCATION":
            location = uniqueValue(
                current: location,
                proposed: ICalendarParser.unescapeText(line.value),
                propertyName: line.name
            )
        case "DESCRIPTION":
            description = uniqueValue(
                current: description,
                proposed: ICalendarParser.unescapeText(line.value),
                propertyName: line.name
            )
        case "DTSTART": start = uniqueTemporalValue(current: start, line: line)
        case "DTEND": end = uniqueTemporalValue(current: end, line: line)
        case "RRULE":
            if line.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.malformedProperty(line.name))
            }
            recurrenceRule = uniqueValue(current: recurrenceRule, proposed: line.value, propertyName: line.name)
        case "EXDATE", "RDATE", "RECURRENCE-ID": unsupportedRecurrenceProperties.insert(line.name)
        case "STATUS":
            let normalizedStatus = line.value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            if ["TENTATIVE", "CONFIRMED", "CANCELLED"].contains(normalizedStatus) {
                status = uniqueValue(current: status, proposed: normalizedStatus, propertyName: line.name)
            } else {
                issues.append(.malformedProperty(line.name))
            }
        default: break
        }
    }

    func build() -> ICalendarEvent {
        ICalendarEvent(
            uid: uid?.nilIfEmpty,
            summary: summary?.nilIfEmpty,
            location: location?.nilIfEmpty,
            description: description?.nilIfEmpty,
            start: start,
            end: end,
            recurrenceRule: recurrenceRule?.nilIfEmpty,
            unsupportedRecurrenceProperties: unsupportedRecurrenceProperties,
            status: status,
            issues: issues
        )
    }

    private mutating func uniqueValue(
        current: String?,
        proposed: String,
        propertyName: String
    ) -> String? {
        guard current == nil else {
            issues.append(.duplicateProperty(propertyName))
            return current
        }
        return proposed
    }

    private mutating func uniqueTemporalValue(
        current: ICalendarTemporalValue?,
        line: ContentLine
    ) -> ICalendarTemporalValue? {
        guard current == nil else {
            issues.append(.duplicateProperty(line.name))
            return current
        }

        switch CalendarDateParser.parse(value: line.value, parameters: line.parameters) {
        case let .success(value): return value
        case let .failure(issue):
            issues.append(issue)
            return nil
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
