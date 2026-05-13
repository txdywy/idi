import Foundation

actor WeatherProvider {
    private var cachedModule: TelemetryModule?
    private var lastFetch: Date?
    private let cacheDuration: TimeInterval = 1_800

    func currentModule() async -> TelemetryModule {
        if let cachedModule, let lastFetch, Date().timeIntervalSince(lastFetch) < cacheDuration {
            return cachedModule
        }

        do {
            let module = try await fetchWeather()
            cachedModule = module
            lastFetch = Date()
            return module
        } catch {
            return cachedModule ?? fallbackModule(detail: "Weather unavailable")
        }
    }

    private func fetchWeather() async throws -> TelemetryModule {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: "31.2304"),
            URLQueryItem(name: "longitude", value: "121.4737"),
            URLQueryItem(name: "current", value: "temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,surface_pressure,wind_speed_10m,wind_gusts_10m,visibility,uv_index"),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,uv_index_max"),
            URLQueryItem(name: "forecast_days", value: "4"),
            URLQueryItem(name: "timezone", value: "auto")
        ]
        let url = components.url!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
        let current = response.current
        let temperature = Int(current.temperature2m.rounded())
        let humidity = Int(current.relativeHumidity2m.rounded())
        let wind = Int(current.windSpeed10m.rounded())
        let precipitationChance = response.daily?.precipitationProbabilityMax.first

        var rows = [
            DetailRow(label: "Location", value: "Shanghai (configured)"),
            DetailRow(label: "Humidity", value: "\(humidity)%"),
            DetailRow(label: "Wind", value: "\(wind) km/h"),
            DetailRow(label: "Precip chance", value: precipitationChance.map { "\($0)% today" } ?? "Not exposed"),
            DetailRow(label: "Precip now", value: String(format: "%.1f mm", current.precipitation ?? 0)),
            DetailRow(label: "Pressure", value: current.surfacePressure.map { String(format: "%.0f hPa", $0) } ?? "Not exposed"),
            DetailRow(label: "Visibility", value: current.visibility.map { String(format: "%.1f km", $0 / 1_000) } ?? "Not exposed"),
            DetailRow(label: "UV", value: current.uvIndex.map { String(format: "%.1f", $0) } ?? response.daily?.uvIndexMax.first.map { String(format: "%.1f max", $0) } ?? "Not exposed"),
            DetailRow(label: "Feels like", value: current.apparentTemperature.map { "\(Int($0.rounded()))°C" } ?? "Not exposed")
        ]
        rows.append(contentsOf: forecastRows(from: response.daily))
        rows.append(DetailRow(label: "Provider", value: "Open-Meteo when Weather is enabled"))

        return TelemetryModule(
            name: "Weather",
            symbol: current.weatherCode.symbol,
            value: "\(temperature)°C",
            detail: "\(current.weatherCode.description) · Shanghai configured",
            accent: .cyan,
            samples: Array(repeating: min(max((current.temperature2m + 10) / 50, 0), 1), count: 18),
            healthState: .normal,
            detailRows: rows
        )
    }

    private func forecastRows(from daily: OpenMeteoResponse.Daily?) -> [DetailRow] {
        guard let daily else { return [] }
        return daily.time.indices.prefix(3).compactMap { index in
            guard daily.temperature2mMax.indices.contains(index),
                  daily.temperature2mMin.indices.contains(index),
                  daily.weatherCode.indices.contains(index) else { return nil }
            let label = index == 0 ? "Today" : shortDate(daily.time[index])
            let rain = daily.precipitationProbabilityMax.indices.contains(index) ? " · rain \(daily.precipitationProbabilityMax[index])%" : ""
            return DetailRow(
                label: label,
                value: "\(Int(daily.temperature2mMin[index].rounded()))–\(Int(daily.temperature2mMax[index].rounded()))°C · \(daily.weatherCode[index].description)\(rain)"
            )
        }
    }

    private func shortDate(_ value: String) -> String {
        let input = DateFormatter()
        input.dateFormat = "yyyy-MM-dd"
        guard let date = input.date(from: value) else { return value }
        let output = DateFormatter()
        output.dateFormat = "E d"
        return output.string(from: date)
    }

    private func fallbackModule(detail: String) -> TelemetryModule {
        TelemetryModule(
            name: "Weather",
            symbol: "cloud",
            value: "offline",
            detail: detail,
            accent: .cyan,
            samples: Array(repeating: 0.44, count: 18),
            healthState: .normal,
            detailRows: [
                DetailRow(label: "Location", value: "Shanghai (configured)"),
                DetailRow(label: "Provider", value: "Open-Meteo when Weather is enabled"),
                DetailRow(label: "Cache", value: cachedModule == nil ? "Empty" : "Expired"),
                DetailRow(label: "Privacy", value: "Disabled module makes no weather request")
            ]
        )
    }
}

private struct OpenMeteoResponse: Decodable {
    let current: Current
    let daily: Daily?

    struct Current: Decodable {
        let temperature2m: Double
        let relativeHumidity2m: Double
        let apparentTemperature: Double?
        let precipitation: Double?
        let weatherCode: Int
        let surfacePressure: Double?
        let windSpeed10m: Double
        let windGusts10m: Double?
        let visibility: Double?
        let uvIndex: Double?

        enum CodingKeys: String, CodingKey {
            case temperature2m = "temperature_2m"
            case relativeHumidity2m = "relative_humidity_2m"
            case apparentTemperature = "apparent_temperature"
            case precipitation
            case weatherCode = "weather_code"
            case surfacePressure = "surface_pressure"
            case windSpeed10m = "wind_speed_10m"
            case windGusts10m = "wind_gusts_10m"
            case visibility
            case uvIndex = "uv_index"
        }
    }

    struct Daily: Decodable {
        let time: [String]
        let weatherCode: [Int]
        let temperature2mMax: [Double]
        let temperature2mMin: [Double]
        let precipitationProbabilityMax: [Int]
        let uvIndexMax: [Double]

        enum CodingKeys: String, CodingKey {
            case time
            case weatherCode = "weather_code"
            case temperature2mMax = "temperature_2m_max"
            case temperature2mMin = "temperature_2m_min"
            case precipitationProbabilityMax = "precipitation_probability_max"
            case uvIndexMax = "uv_index_max"
        }
    }
}

private extension Int {
    var description: String {
        switch self {
        case 0:
            return "Clear"
        case 1...3:
            return "Partly cloudy"
        case 45, 48:
            return "Fog"
        case 51...67, 80...82:
            return "Rain"
        case 71...77, 85...86:
            return "Snow"
        case 95...99:
            return "Thunderstorm"
        default:
            return "Forecast"
        }
    }

    var symbol: String {
        switch self {
        case 0:
            return "sun.max"
        case 1...3:
            return "cloud.sun"
        case 45, 48:
            return "cloud.fog"
        case 51...67, 80...82:
            return "cloud.rain"
        case 71...77, 85...86:
            return "cloud.snow"
        case 95...99:
            return "cloud.bolt.rain"
        default:
            return "cloud"
        }
    }
}
