import Foundation

// Modelos de la app, independientes de la red de la que vengan los datos.
// Cada fuente (`StationSource`) los rellena a partir de su propio formato; los campos
// tienen valor por defecto para que una red que no mida algo simplemente no lo ponga.

/// Lectura en directo de una estación.
struct StationReading: Equatable {
    /// Viento actual, promedio y racha (kn).
    var actual: Double?
    var promedio: Double?
    var racha: Double?
    /// Rumbo de donde viene el viento: nombre ("SW") y grados.
    var direccion = "—"
    var grados: Double?
    /// Nombre local del viento ("Garbí"), si la estación lo da.
    var nombre = ""
    var temperatura: Double?
    var humedad: Double?
    var presion: Double?
    var actualizado = ""
    var tendencia: Trend?
    var racheado = false
    /// Variación del viento en los últimos 15 min (kn).
    var delta: Double?
    var media15: Double?
    var rachamax15: Double?

    enum Trend: String {
        case subiendo, bajando, estable
    }

    /// Lectura de ejemplo para vistas previas y el selector de complicaciones.
    static let placeholder = StationReading(
        actual: 12.2, promedio: 10.4, racha: 15.6, direccion: "SW", grados: 225, nombre: "GARBÍ",
        temperatura: 22, humedad: 60, presion: 1015, tendencia: .subiendo, delta: 1.3)
}

/// Viento de las últimas horas, una muestra cada `pasoMin` minutos.
struct WindHistory {
    var inicio: Date
    var pasoMin = 1
    var nominal: [Double?]
    var racha: [Double?] = []
    /// Grados de donde viene el viento.
    var grados: [Double?] = []

    /// Hacia dónde ha oscilado el viento en los últimos `minutes` minutos con dato:
    /// dirección media y lo que se ha separado de ella hacia cada lado (grados).
    func directionSpread(minutes: Int = 15) -> (mean: Double, left: Double, right: Double)? {
        let recent = grados.compactMap { $0 }.suffix(max(1, minutes / max(pasoMin, 1)))
        guard recent.count >= 2 else { return nil }
        let x = recent.map { sin($0 * .pi / 180) }.reduce(0, +)
        let y = recent.map { cos($0 * .pi / 180) }.reduce(0, +)
        let mean = (atan2(x, y) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
        // diferencia con signo respecto a la media, entre -180 y 180
        let diffs = recent.map { ($0 - mean + 540).truncatingRemainder(dividingBy: 360) - 180 }
        return (mean, max(0, -(diffs.min() ?? 0)), max(0, diffs.max() ?? 0))
    }

    /// Tres horas de viento inventado (de 6 a 14 kn) para las vistas previas.
    static let placeholder: WindHistory = {
        let nominal = (0..<180).map { i in (10 + 4 * sin(Double(i) / 25)).rounded() }
        return WindHistory(
            inicio: Date.now.addingTimeInterval(-3 * 3600),
            nominal: nominal,
            racha: nominal.enumerated().map { i, v in v + 2 + Double(i % 7) / 2 },
            grados: (0..<180).map { i in (225 + 15 * sin(Double(i) / 9)).rounded() })
    }()

    struct Sample: Identifiable {
        var id: Date { date }
        var date: Date
        var nominal: Double?
        var racha: Double?
    }

    var samples: [Sample] {
        let paso = TimeInterval(pasoMin * 60)
        return nominal.indices.map { i in
            Sample(date: inicio.addingTimeInterval(Double(i) * paso),
                   nominal: nominal[i],
                   racha: i < racha.count ? racha[i] : nil)
        }
    }
}

/// Previsión horaria para la zona de la estación.
struct Forecast {
    /// Quién hace la previsión ("AEMET"): hay que citarlo.
    var fuente: String
    var hours: [Hour]

    struct Hour: Identifiable {
        var id: Date { date }
        var date: Date
        var viento: Double?
        var racha: Double?
        var direccion = "—"
        var grados: Double?
        var temperatura: Double?
        /// Estado del cielo en texto ("Poco nuboso").
        var cielo = ""
    }

    /// Horas desde la actual en adelante.
    func upcoming(from now: Date = .now, count: Int? = nil) -> [Hour] {
        let start = now.addingTimeInterval(-3600)
        let next = hours.filter { $0.date > start }
        return count.map { Array(next.prefix($0)) } ?? next
    }

    /// Dos días de viento inventado (térmico de tarde) para las vistas previas.
    static let placeholder: Forecast = {
        let today = Calendar.current.startOfDay(for: .now)
        let hours = (0..<48).map { i -> Hour in
            let h = i % 24
            let v = max(2, 12 * sin(Double(h - 9) / 10 * .pi)).rounded()
            let seaBreeze = h >= 11 && h <= 19
            return Hour(date: today.addingTimeInterval(Double(i) * 3600), viento: v, racha: (v * 1.4).rounded(),
                        direccion: seaBreeze ? "SW" : "N", grados: seaBreeze ? 225 : 0,
                        temperatura: Double(16 + h / 3), cielo: h % 5 == 0 ? "Nuboso" : "Poco nuboso")
        }
        return Forecast(fuente: "AEMET", hours: hours)
    }()
}
