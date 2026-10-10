import CoreLocation
import Foundation
import MinoKit
import Observation
import WeatherKit

/// Daily forecasts from Apple WeatherKit, with a seasonal estimate whenever they are unavailable
/// (no network, location refused), so Mino always has an answer.
@Observable
@MainActor
final class WeatherStore {
    private(set) var forecasts: [Date: DayForecast] = [:]
    private(set) var attribution: WeatherAttribution?
    /// Changes whenever new forecasts arrive, so plans can be refreshed.
    private(set) var version = 0

    private let location = LocationProvider()
    @ObservationIgnored private var lastRefresh: Date?
    private let calendar = Calendar.current

    func forecast(for day: Date) -> DayForecast {
        forecasts[calendar.startOfDay(for: day)] ?? .seasonalEstimate(for: day, calendar: calendar)
    }

    func refresh() async {
        if attribution == nil {
            // Needed to credit Apple Weather; it does not depend on the location.
            attribution = try? await WeatherService.shared.attribution
        }
        if let lastRefresh, Date.now.timeIntervalSince(lastRefresh) < 30 * 60 { return }
        guard let place = await location.currentLocation() else { return }
        do {
            let service = WeatherService.shared
            let (daily, hourly) = try await service.weather(for: place, including: .daily, .hourly)
            var updated: [Date: DayForecast] = [:]
            for day in daily {
                let start = calendar.startOfDay(for: day.date)
                let morning = hourly.first { hour in
                    calendar.isDate(hour.date, inSameDayAs: start) && calendar.component(.hour, from: hour.date) == 8
                }
                let high = day.highTemperature.converted(to: .celsius).value
                let low = day.lowTemperature.converted(to: .celsius).value
                updated[start] = DayForecast(
                    date: start,
                    morningC: morning?.apparentTemperature.converted(to: .celsius).value ?? low + (high - low) * 0.25,
                    highC: high,
                    precipitationChance: day.precipitationChance,
                    condition: Self.sky(for: day)
                )
            }
            forecasts = updated
            lastRefresh = .now
            version += 1
        } catch {
            // Keep the seasonal estimate; the next refresh will try again.
        }
    }

    private static func sky(for day: WeatherKit.DayWeather) -> SkyCondition {
        switch day.precipitation {
        case .snow, .sleet: return .snow
        case .rain, .hail, .mixed: return day.precipitationChance >= 0.3 ? .rain : .cloudy
        default: return day.condition == .clear || day.condition == .mostlyClear ? .clear : .cloudy
        }
    }
}
