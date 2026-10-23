import Foundation

/// Acceso a los datos de 17nudos.com, compartido por la app y la complicación.
///
/// Los endpoints responden "Acceso denegado" si la petición no viene de la web,
/// por eso se envía el `Referer` de 17nudos.com igual que hace el navegador.
enum StationAPI {
    private static let base = URL(string: "https://www.17nudos.com/")!
    private static let stationURL = URL(string: "estacion_datos_mdx.php", relativeTo: base)!
    private static let historyURL = URL(string: "grafica_datos_mdx.php", relativeTo: base)!

    private static let session: URLSession = {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        cfg.timeoutIntervalForRequest = 15
        return URLSession(configuration: cfg)
    }()

    static func reading() async throws -> StationReading {
        try await fetch(stationURL, query: [:])
    }

    static func history(hours: Int) async throws -> WindHistory {
        try await fetch(historyURL, query: ["horas": "\(hours)"])
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
