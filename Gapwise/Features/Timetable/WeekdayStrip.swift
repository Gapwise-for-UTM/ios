import SwiftUI

struct WeekdayStrip: View {
    let dates: [Date]
    let selectedDate: Date
    let calendar: Calendar
    let onSelect: (Date) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: GapwiseSpacing.compact) {
                ForEach(dates, id: \.self) { date in
                    dayButton(for: date)
                }
            }
            .padding(.horizontal, GapwiseSpacing.standard)
        }
        .accessibilityLabel("Days in selected week")
    }

    private func dayButton(for date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)

        return Button {
            onSelect(date)
        } label: {
            VStack(spacing: 5) {
                Text(date.formatted(.dateTime.weekday(.narrow)))
                    .font(.caption.weight(.medium))
                Text(date.formatted(.dateTime.day()))
                    .font(.body.weight(isSelected ? .bold : .regular))
                Circle()
                    .fill(isToday ? Color.gapwiseAccent : .clear)
                    .frame(width: 4, height: 4)
            }
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .frame(minWidth: 44, minHeight: 58)
            .padding(.horizontal, 3)
            .background(
                isSelected ? Color.gapwiseAccent : Color.clear,
                in: RoundedRectangle(cornerRadius: GapwiseRadius.card)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
