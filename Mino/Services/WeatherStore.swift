import CoreLocation
import Foundation
import MinoKit
import Observation
import WeatherKit

/// Where the location permission stands, in the parent's terms.
enum LocationAccess {
    case notAsked, refused, allowed
}

/// Daily forecasts from Apple WeatherKit, with a seasonal estimate whenever they are unavailable
/// (no network, location refused), so Mino always has an answer, and says why.
@Observable
@MainActor
final class WeatherStore {
    private(set) var forecasts: [Date: DayForecast] = [:]
    private(set) var attribution: WeatherAttribution?
    /// Changes whenever new forecasts arrive, so plans can be refreshed.
    private(set) var version = 0
    private(set) var locationAccess: LocationAccess = .notAsked
    /// When Apple Weather last answered.
    private(set) var lastUpdate: Date?
    /// Why the last attempt failed, in plain words; nil when the forecast is live.
    private(set) var failure: String?

    private let location = LocationProvider()
    private let calendar = Calendar.current
    /// One request at a time: overlapping ones would only see a busy location provider.
    @ObservationIgnored private var isRefreshing = false

    /// Reads the current permission without asking anything.
    func updateLocationAccess() {
        locationAccess = location.access
    }

    func forecast(for day: Date) -> DayForecast {
        forecasts[calendar.startOfDay(for: day)] ?? .seasonalEstimate(for: day, calendar: calendar)
    }

    /// Fetches the forecast, at most every 30 minutes unless `force` is set (a parent's tap, or
    /// coming back to the app after changing a permission).
    func refresh(force: Bool = false) async {
        if attribution == nil {
            // Needed to credit Apple Weather; it does not depend on the location.
            attribution = try? await WeatherService.shared.attribution
        }
        if !force, let lastUpdate, Date.now.timeIntervalSince(lastUpdate) < 30 * 60 { return }
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let place = await location.currentLocation()
        locationAccess = location.access
        guard let place else {
            failure = locationAccess == .refused
                ? "La localisation est refusée pour Mino."
                : "La position de l'iPhone est introuvable pour le moment."
            return
        }
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
            lastUpdate = .now
            failure = nil
            version += 1
        } catch {
            failure = Self.explanation(of: error)
        }
    }

    /// WeatherKit authenticates the app with a token tied to its signing; when Apple refuses it
    /// (permission denied, or the daemon's JWT error), the fix is on the developer account.
    private static func explanation(of error: Error) -> String {
        let isAuthentication: Bool
        if case WeatherError.permissionDenied = error {
            isAuthentication = true
        } else {
            isAuthentication = String(describing: error).contains("JWTAuthenticator")
        }
        return isAuthentication
            ? "Apple Météo ne reconnaît pas encore l'app : WeatherKit n'est pas actif dans le profil de signature de \(Bundle.main.bundleIdentifier ?? "l'app")."
            : "Apple Météo n'a pas répondu (\(error.localizedDescription))."
    }

    private static func sky(for day: WeatherKit.DayWeather) -> SkyCondition {
        switch day.precipitation {
        case .snow, .sleet: return .snow
        case .rain, .hail, .mixed: return day.precipitationChance >= 0.3 ? .rain : .cloudy
        default: return day.condition == .clear || day.condition == .mostlyClear ? .clear : .cloudy
        }
    }
}
