import Foundation

/// Lectura en directo de la estación (`estacion_datos_mdx.php`).
/// El servidor manda casi todo como texto ("5.2") y puede devolver "NoLink"
/// si la estación pierde conexión, así que los números se decodifican con tolerancia.
struct StationReading: Decodable, Equatable {
    var actual: Double?
    var promedio: Double?
    var racha: Double?
    var direccion: String
    var grados: Double?
    var nombre: String
    var temperatura: Double?
    var humedad: Double?
    var presion: Double?
    var actualizado: String
    var tendencia: Trend?
    var racheado: Bool
    var delta: Double?
    var media15: Double?
    var rachamax15: Double?

    /// Lectura de ejemplo para vistas previas y el selector de complicaciones.
    static let placeholder = try! JSONDecoder().decode(StationReading.self, from: Data("""
        {"actual":"12.2","promedio":"10.4","racha":"15.6","direccion":"SW","grados":"225",
         "nombre":"GARBÍ","temperatura":"22.0","humedad":"60","presion":"1015.0",
         "actualizado":"","tendencia":"subiendo","racheado":false,"delta":1.3}
        """.utf8))

    enum Trend: String, Decodable {
        case subiendo, bajando, estable
    }

    private enum CodingKeys: String, CodingKey {
        case actual, promedio, racha, direccion, grados, nombre, temperatura, humedad,
             presion, actualizado, tendencia, racheado, delta, media15, rachamax15
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        actual = c.flexibleDouble(.actual)
        promedio = c.flexibleDouble(.promedio)
        racha = c.flexibleDouble(.racha)
        grados = c.flexibleDouble(.grados)
        temperatura = c.flexibleDouble(.temperatura)
        humedad = c.flexibleDouble(.humedad)
        presion = c.flexibleDouble(.presion)
        delta = c.flexibleDouble(.delta)
        media15 = c.flexibleDouble(.media15)
        rachamax15 = c.flexibleDouble(.rachamax15)
        direccion = c.cleanString(.direccion) ?? "—"
        nombre = c.cleanString(.nombre) ?? ""
        actualizado = c.cleanString(.actualizado) ?? ""
        tendencia = (try? c.decodeIfPresent(String.self, forKey: .tendencia)).flatMap { $0.flatMap(Trend.init(rawValue:)) }
        racheado = (try? c.decodeIfPresent(Bool.self, forKey: .racheado)) ?? false
    }
}

/// Serie del día (`grafica_datos_mdx.php?horas=N`), una muestra por `paso_min` minutos.
struct WindHistory: Decodable {
    var inicio: Date
    var pasoMin: Int
    var nominal: [Double?]
    var racha: [Double?]

    private enum CodingKeys: String, CodingKey {
        case inicio, paso_min, nominal, racha
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let txt = try c.decode(String.self, forKey: .inicio)
        guard let d = ISO8601DateFormatter().date(from: txt) else {
            throw DecodingError.dataCorruptedError(forKey: .inicio, in: c, debugDescription: "Fecha no válida: \(txt)")
        }
        inicio = d
        pasoMin = (try? c.decode(Int.self, forKey: .paso_min)) ?? 1
        nominal = (try? c.decode([Double?].self, forKey: .nominal)) ?? []
        racha = (try? c.decode([Double?].self, forKey: .racha)) ?? []
    }

    /// Tres horas de viento inventado (de 6 a 14 kn) para las vistas previas.
    static let placeholder: WindHistory = {
        let nominal = (0..<180).map { i in (10 + 4 * sin(Double(i) / 25)).rounded() }
        let racha = nominal.enumerated().map { i, v in v + 2 + Double(i % 7) / 2 }
        let inicio = ISO8601DateFormatter().string(from: Date.now.addingTimeInterval(-3 * 3600))
        let json = #"{"inicio":"\#(inicio)","paso_min":1,"nominal":\#(nominal),"racha":\#(racha)}"#
        return try! JSONDecoder().decode(WindHistory.self, from: Data(json.utf8))
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

/// Previsión horaria de AEMET que publica la web (`prevision_mdx.php`).
/// Las horas vienen en hora local de Castelldefels, separadas por días.
struct Forecast: Decodable {
    var fuente: String
    var hours: [Hour]

    struct Hour: Identifiable {
        var id: Date { date }
        var date: Date
        var viento: Double?
        var racha: Double?
        var direccion: String
        var grados: Double?
        var temperatura: Double?
        var cielo: String
    }

    private enum CodingKeys: String, CodingKey { case fuente, dias }

    private struct Day: Decodable {
        var fecha: String
        var horas: [RawHour]
    }

    private struct RawHour: Decodable {
        var hora: Int
        var viento: Double?, racha: Double?, grados: Double?, temp: Double?
        var dir: String, cielo: String

        private enum CodingKeys: String, CodingKey {
            case hora, viento_kn, racha_kn, grados, temp, dir, cielo
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            hora = try c.decode(Int.self, forKey: .hora)
            viento = c.flexibleDouble(.viento_kn)
            racha = c.flexibleDouble(.racha_kn)
            grados = c.flexibleDouble(.grados)
            temp = c.flexibleDouble(.temp)
            dir = c.cleanString(.dir) ?? "—"
            cielo = c.cleanString(.cielo) ?? ""
        }
    }

    private static let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Madrid")!
        return cal
    }()

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fuente = c.cleanString(.fuente) ?? "AEMET"
        let dias = try c.decode([Day].self, forKey: .dias)
        hours = dias.flatMap { day -> [Hour] in
            let parts = day.fecha.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 3 else { return [] }
            return day.horas.compactMap { h in
                let comps = DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: h.hora)
                guard let date = Self.calendar.date(from: comps) else { return nil }
                return Hour(date: date, viento: h.viento, racha: h.racha, direccion: h.dir,
                            grados: h.grados, temperatura: h.temp, cielo: h.cielo)
            }
        }
    }

    /// Horas desde la actual en adelante.
    func upcoming(from now: Date = .now, count: Int? = nil) -> [Hour] {
        let start = now.addingTimeInterval(-3600)
        let next = hours.filter { $0.date > start }
        return count.map { Array(next.prefix($0)) } ?? next
    }

    /// Dos días de viento inventado (térmico de tarde) para las vistas previas.
    static let placeholder: Forecast = {
        let cal = calendar
        let today = cal.startOfDay(for: .now)
        let dias = (0..<2).map { d -> String in
            let date = cal.date(byAdding: .day, value: d, to: today)!
            let c = cal.dateComponents([.year, .month, .day], from: date)
            let horas = (0..<24).map { h -> String in
                let v = max(2, 12 * sin(Double(h - 9) / 10 * .pi))
                let deg = h >= 11 && h <= 19 ? 225 : 0
                let cielo = h % 5 == 0 ? "Nuboso" : "Poco nuboso"
                return #"{"hora":\#(h),"viento_kn":\#(v.rounded()),"racha_kn":\#((v * 1.4).rounded()),"dir":"\#(deg == 0 ? "N" : "SW")","grados":\#(deg),"temp":\#(16 + h / 3),"cielo":"\#(cielo)"}"#
            }
            let fecha = String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
            return #"{"fecha":"\#(fecha)","horas":[\#(horas.joined(separator: ","))]}"#
        }
        let json = #"{"fuente":"AEMET","dias":[\#(dias.joined(separator: ","))]}"#
        return try! JSONDecoder().decode(Forecast.self, from: Data(json.utf8))
    }()
}

private extension KeyedDecodingContainer {
    func flexibleDouble(_ key: Key) -> Double? {
        if let d = try? decodeIfPresent(Double.self, forKey: key) { return d }
        if let s = try? decodeIfPresent(String.self, forKey: key) {
            return Double(s.replacingOccurrences(of: ",", with: "."))
        }
        return nil
    }

    func cleanString(_ key: Key) -> String? {
        guard let s = try? decodeIfPresent(String.self, forKey: key), s != "NoLink", !s.isEmpty else { return nil }
        return s
    }
}
