import SwiftUI

struct MeetingCard: View {
    let meeting: CourseMeeting
    let date: Date
    var isHighlighted = false

    private let calendar = Calendar.gapwiseToronto

    var body: some View {
        HStack(alignment: .top, spacing: GapwiseSpacing.standard) {
            VStack(alignment: .leading, spacing: 3) {
                Text(GapwiseFormatters.time(meeting.startTime, on: date, calendar: calendar))
                    .font(.subheadline.weight(.semibold))
                Text(GapwiseFormatters.time(meeting.endTime, on: date, calendar: calendar))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 68, alignment: .leading)

            RoundedRectangle(cornerRadius: 2)
                .fill(isHighlighted ? Color.gapwiseSuccess : .gapwiseAccent)
                .frame(width: 4)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: GapwiseSpacing.compact) {
                HStack(alignment: .firstTextBaseline) {
                    Text(meeting.courseCode.rawValue)
                        .font(.headline)
                    Spacer(minLength: GapwiseSpacing.compact)
                    Text(meeting.campus.shortName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.gapwiseAccent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.gapwiseAccent.opacity(0.12), in: Capsule())
                }

                if let courseTitle = meeting.courseTitle {
                    Text(courseTitle)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(2)
                }

                Text(meeting.displaySection)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let location = meeting.location {
                    Label(location.displayName, systemImage: location.systemImageName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .gapwiseCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        let start = GapwiseFormatters.time(meeting.startTime, on: date, calendar: calendar)
        let end = GapwiseFormatters.time(meeting.endTime, on: date, calendar: calendar)
        let location = meeting.location.map { ", \($0.displayName)" } ?? ""
        return
            "\(meeting.courseCode.rawValue), \(meeting.displaySection), \(start) to \(end), \(meeting.campus.shortName)\(location)"
    }
}

#if DEBUG
    #Preview {
        if let meeting = PreviewData.timetable.meetings.first {
            MeetingCard(meeting: meeting, date: .now)
                .padding()
        }
    }
#endif
