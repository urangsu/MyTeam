import Foundation

enum KMAForecastProduct: String, Sendable {
    case ultraShortNowcast
    case ultraShortForecast
    case villageForecast
}

struct KMABaseSlot: Sendable, Equatable {
    let date: String
    let time: String
}

enum KMABaseTimePolicy {
    private nonisolated static let koreaTimeZone = TimeZone(identifier: "Asia/Seoul")!
    private nonisolated static let villageHours = [2, 5, 8, 11, 14, 17, 20, 23]

    nonisolated static func candidates(
        for product: KMAForecastProduct,
        now: Date,
        limit: Int = 2
    ) -> [KMABaseSlot] {
        guard limit > 0 else { return [] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = koreaTimeZone

        let first: Date
        switch product {
        case .ultraShortNowcast:
            let hour = calendar.dateInterval(of: .hour, for: now)?.start ?? now
            let availableAt = calendar.date(byAdding: .minute, value: 10, to: hour) ?? hour
            first = now >= availableAt ? hour : (calendar.date(byAdding: .hour, value: -1, to: hour) ?? hour)
        case .ultraShortForecast:
            let hour = calendar.dateInterval(of: .hour, for: now)?.start ?? now
            let base = calendar.date(byAdding: .minute, value: 30, to: hour) ?? hour
            let availableAt = calendar.date(byAdding: .minute, value: 15, to: base) ?? base
            first = now >= availableAt ? base : (calendar.date(byAdding: .hour, value: -1, to: base) ?? base)
        case .villageForecast:
            first = latestVillageBase(at: now, calendar: calendar)
        }

        return (0..<limit).compactMap { offset in
            let stepHours = product == .villageForecast ? -3 * offset : -offset
            guard let date = calendar.date(byAdding: .hour, value: stepHours, to: first) else { return nil }
            return slot(from: date, calendar: calendar)
        }
    }

    private nonisolated static func latestVillageBase(at now: Date, calendar: Calendar) -> Date {
        let startOfDay = calendar.startOfDay(for: now)
        for hour in villageHours.reversed() {
            guard let base = calendar.date(byAdding: .hour, value: hour, to: startOfDay),
                  let availableAt = calendar.date(byAdding: .minute, value: 10, to: base) else {
                continue
            }
            if now >= availableAt { return base }
        }
        let previousDay = calendar.date(byAdding: .day, value: -1, to: startOfDay) ?? startOfDay
        return calendar.date(byAdding: .hour, value: 23, to: previousDay) ?? previousDay
    }

    private nonisolated static func slot(from date: Date, calendar: Calendar) -> KMABaseSlot {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return KMABaseSlot(
            date: String(format: "%04d%02d%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0),
            time: String(format: "%02d%02d", components.hour ?? 0, components.minute ?? 0)
        )
    }
}
