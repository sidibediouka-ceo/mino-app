import SwiftUI

/// A month calendar whose days carry dots, one per child with an outfit that day, in the
/// child's colour. Weeks start on Monday, as in France.
struct MonthCalendar: View {
    @Binding var selection: Date
    let lastDay: Date
    /// Colours of the children with an outfit on a given day (start of day).
    let markers: [Date: [Color]]

    @State private var month: Date

    private static let weekdays = ["L", "M", "M", "J", "V", "S", "D"]

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "fr_FR")
        calendar.firstWeekday = 2
        return calendar
    }()

    init(selection: Binding<Date>, lastDay: Date, markers: [Date: [Color]]) {
        _selection = selection
        self.lastDay = lastDay
        self.markers = markers
        _month = State(initialValue: Self.startOfMonth(selection.wrappedValue))
    }

    var body: some View {
        let calendar = Self.calendar
        let days = Self.days(of: month)
        let leadingBlanks = (calendar.component(.weekday, from: month) - calendar.firstWeekday + 7) % 7
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: month) ?? month

        VStack(spacing: 12) {
            HStack {
                Button { shiftMonth(by: -1) } label: { Image(systemName: "chevron.left") }
                    .accessibilityLabel("Mois précédent")
                Spacer()
                Text(Formatting.month(month))
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Button { shiftMonth(by: 1) } label: { Image(systemName: "chevron.right") }
                    .disabled(nextMonth > lastDay)
                    .accessibilityLabel("Mois suivant")
            }
            .font(.headline)
            .foregroundStyle(Theme.accent)

            HStack(spacing: 0) {
                ForEach(Self.weekdays.indices, id: \.self) { index in
                    Text(Self.weekdays[index])
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.secondaryText)
                        .frame(maxWidth: .infinity)
                }
            }
            .accessibilityHidden(true)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 6) {
                ForEach(-leadingBlanks..<0, id: \.self) { _ in Color.clear.frame(height: 44) }
                ForEach(days, id: \.self) { day in
                    dayCell(day)
                }
            }
        }
        .padding(12)
    }

    private func dayCell(_ day: Date) -> some View {
        let calendar = Self.calendar
        let isSelected = calendar.isDate(day, inSameDayAs: selection)
        let isToday = calendar.isDateInToday(day)
        let colors = markers[calendar.startOfDay(for: day)] ?? []
        return Button { selection = day } label: {
            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.system(.body, design: .rounded).weight(isToday || isSelected ? .bold : .regular))
                    .foregroundStyle(isSelected ? Theme.onAccent : (isToday ? Theme.accent : Theme.ink))
                    .frame(width: 34, height: 34)
                    .background(isSelected ? Theme.accent : .clear, in: Circle())
                HStack(spacing: 3) {
                    ForEach(colors.indices, id: \.self) { index in
                        Circle().fill(colors[index]).frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
        .disabled(day > lastDay)
        .opacity(day > lastDay ? 0.3 : 1)
        .accessibilityLabel(Formatting.longDate(day) + (colors.isEmpty ? "" : ", \(Formatting.count(colors.count, "tenue", "tenues"))"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func shiftMonth(by value: Int) {
        if let shifted = Self.calendar.date(byAdding: .month, value: value, to: month) {
            withAnimation(.snappy) { month = shifted }
        }
    }

    private static func startOfMonth(_ date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    private static func days(of month: Date) -> [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        return range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: month) }
    }
}
