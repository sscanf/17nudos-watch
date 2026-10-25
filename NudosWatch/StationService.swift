import Foundation
import Observation

/// Estado de la app: última lectura de la estación elegida, gráfica y previsión.
@MainActor
@Observable
final class StationService {
    let station: Station
    private(set) var reading: StationReading?
    private(set) var history: WindHistory?
    private(set) var forecast: Forecast?
    private var forecastFetch: Date?
    private(set) var lastFetch: Date?
    private(set) var error: String?
    private(set) var isLoading = false

    /// Horas de histórico que se muestran en la gráfica.
    static let historyHours = 3

    /// En el lienzo de Xcode no se descarga nada: se usan datos de ejemplo.
    static let isPreview: Bool = {
        // según la versión de Xcode, el lienzo define una u otra
        let env = ProcessInfo.processInfo.environment
        return env["XCODE_RUNNING_FOR_PREVIEWS"] == "1" || env["XCODE_RUNNING_FOR_PLAYGROUNDS"] == "1"
    }()

    /// AEMET actualiza la previsión pocas veces al día.
    static let forecastEvery: TimeInterval = 30 * 60

    init(station: Station = .selected, reading: StationReading? = nil, history: WindHistory? = nil,
         forecast: Forecast? = nil) {
        self.station = station
        self.reading = reading
        self.history = history
        self.forecast = forecast
    }

    static var preview: StationService {
        StationService(reading: .placeholder, history: .placeholder, forecast: .placeholder)
    }

    func refresh(includeHistory: Bool = true) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let source = station.source
            async let r = source.reading()
            if includeHistory, source.hasHistory {
                // la gráfica es secundaria: si falla, se conserva la anterior
                history = (try? await source.history(hours: Self.historyHours)) ?? history
            }
            if source.hasForecast, forecastFetch.map({ Date.now.timeIntervalSince($0) > Self.forecastEvery }) ?? true,
               let f = try? await source.forecast() {
                forecast = f
                forecastFetch = .now
            }
            reading = try await r
            reading.map(WindAlarm.check)
            lastFetch = .now
            error = nil
        } catch {
            self.error = "Sin conexión con la estación"
        }
    }
}
