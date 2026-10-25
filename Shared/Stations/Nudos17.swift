import Foundation

extension Station {
    /// Estación de 17nudos.com en la playa de Castelldefels.
    static let nudos17 = Station(
        id: "17nudos",
        name: "17nudos",
        place: "Castelldefels",
        latitude: 41.2635,
        longitude: 1.9820,
        attribution: "Datos de 17nudos.com · previsión de AEMET",
        cameras: [
            Camera(name: "Escola Garbí",
                   embed: URL(string: "https://camstreamer.com/embed/209f5b9f1755eec/S-28530")!,
                   fallbackVideoID: "oe5GPi_C7Go",
                   referer: Nudos17Source.base),
            Camera(name: "Hacia Sitges",
                   embed: URL(string: "https://camstreamer.com/yt-embed/90b6a66d6c090c4/S-13556")!,
                   fallbackVideoID: "s6YqEV6Fs5M",
                   referer: Nudos17Source.base),
        ],
        source: Nudos17Source())
}

/// Datos de 17nudos.com.
///
/// Los endpoints responden "Acceso denegado" si la petición no viene de la web,
/// por eso se envía el `Referer` de 17nudos.com igual que hace el navegador.
/// El JSON trae casi todos los números como texto ("5.2") y puede traer "NoLink"
/// si la estación pierde conexión, así que se decodifica con tolerancia.
struct Nudos17Source: StationSource {
    static let base = URL(string: "https://www.17nudos.com/")!
    private static let stationURL = URL(string: "estacion_datos_mdx.php", relativeTo: base)!
    private static let historyURL = URL(string: "grafica_datos_mdx.php", relativeTo: base)!
    private static let forecastURL = URL(string: "prevision_mdx.php", relativeTo: base)!

    private static let session: URLSession = {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        cfg.timeoutIntervalForRequest = 15
        return URLSession(configuration: cfg)
    }()

    func reading() async throws -> StationReading {
        let raw: RawReading = try await Self.fetch(Self.stationURL, query: [:])
        return raw.model
    }

    var hasHistory: Bool { true }

    func history(hours: Int) async throws -> WindHistory {
        let raw: RawHistory = try await Self.fetch(Self.historyURL, query: ["horas": "\(hours)"])
        return raw.model
    }

    var hasForecast: Bool { true }

    func forecast() async throws -> Forecast {
        let raw: RawForecast = try await Self.fetch(Self.forecastURL, query: [:])
        return raw.model
    }

    private static func fetch<T: Decodable>(_ url: URL, query: [String: String]) async throws -> T {
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: true)!
        comps.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
            + [URLQueryItem(name: "t", value: String(Int(Date().timeIntervalSince1970 * 1000)))]
        var req = URLRequest(url: comps.url!)
        req.setValue(base.absoluteString, forHTTPHeaderField: "Referer")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - Formato de 17nudos

/// `estacion_datos_mdx.php`
private struct RawReading: Decodable {
    let model: StationReading

    private enum CodingKeys: String, CodingKey {
        case actual, promedio, racha, direccion, grados, nombre, temperatura, humedad,
             presion, actualizado, tendencia, racheado, delta, media15, rachamax15
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        model = StationReading(
            actual: c.flexibleDouble(.actual),
            promedio: c.flexibleDouble(.promedio),
            racha: c.flexibleDouble(.racha),
            direccion: c.cleanString(.direccion) ?? "—",
            grados: c.flexibleDouble(.grados),
            nombre: c.cleanString(.nombre) ?? "",
            temperatura: c.flexibleDouble(.temperatura),
            humedad: c.flexibleDouble(.humedad),
            presion: c.flexibleDouble(.presion),
            actualizado: c.cleanString(.actualizado) ?? "",
            tendencia: c.cleanString(.tendencia).flatMap(StationReading.Trend.init(rawValue:)),
            racheado: (try? c.decodeIfPresent(Bool.self, forKey: .racheado)) ?? false,
            delta: c.flexibleDouble(.delta),
            media15: c.flexibleDouble(.media15),
            rachamax15: c.flexibleDouble(.rachamax15))
    }
}

/// `grafica_datos_mdx.php?horas=N`: una muestra por `paso_min` minutos.
private struct RawHistory: Decodable {
    let model: WindHistory

    private enum CodingKeys: String, CodingKey {
        case inicio, paso_min, nominal, racha, grados
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let txt = try c.decode(String.self, forKey: .inicio)
        guard let inicio = ISO8601DateFormatter().date(from: txt) else {
            throw DecodingError.dataCorruptedError(forKey: .inicio, in: c, debugDescription: "Fecha no válida: \(txt)")
        }
        model = WindHistory(
            inicio: inicio,
            pasoMin: (try? c.decode(Int.self, forKey: .paso_min)) ?? 1,
            nominal: (try? c.decode([Double?].self, forKey: .nominal)) ?? [],
            racha: (try? c.decode([Double?].self, forKey: .racha)) ?? [],
            grados: (try? c.decode([Double?].self, forKey: .grados)) ?? [])
    }
}

/// `prevision_mdx.php`: previsión horaria de AEMET que publica la web, ~45 h.
/// Las horas vienen en hora local de Castelldefels, separadas por días.
private struct RawForecast: Decodable {
    let model: Forecast

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
        let dias = try c.decode([Day].self, forKey: .dias)
        let hours = dias.flatMap { day -> [Forecast.Hour] in
            let parts = day.fecha.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 3 else { return [] }
            return day.horas.compactMap { h in
                let comps = DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: h.hora)
                guard let date = Self.calendar.date(from: comps) else { return nil }
                return Forecast.Hour(date: date, viento: h.viento, racha: h.racha, direccion: h.dir,
                                     grados: h.grados, temperatura: h.temp, cielo: h.cielo)
            }
        }
        model = Forecast(fuente: c.cleanString(.fuente) ?? "AEMET", hours: hours)
    }
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
