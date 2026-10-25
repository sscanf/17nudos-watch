import Foundation

/// Red o web de la que se leen los datos de una estación.
///
/// Para añadir otra (Holfuy, WeatherLink, la web de otro club…): se implementa este
/// protocolo en `Shared/Stations/` y se da de alta la estación en `Station.all`.
/// Lo único obligatorio es la lectura en directo; el histórico y la previsión son opcionales
/// y la app esconde sus páginas si la red no los da.
protocol StationSource: Sendable {
    func reading() async throws -> StationReading

    var hasHistory: Bool { get }
    /// Viento de las últimas `hours` horas (gráfica, variación de dirección).
    func history(hours: Int) async throws -> WindHistory

    var hasForecast: Bool { get }
    func forecast() async throws -> Forecast
}

extension StationSource {
    var hasHistory: Bool { false }
    func history(hours: Int) async throws -> WindHistory { throw StationError.unsupported }

    var hasForecast: Bool { false }
    func forecast() async throws -> Forecast { throw StationError.unsupported }
}

enum StationError: Error {
    /// La red de esta estación no ofrece ese dato.
    case unsupported
}

/// Una estación que la app sabe mostrar.
struct Station: Identifiable, Sendable {
    /// Identificador estable: se guarda en los ajustes.
    let id: String
    let name: String
    /// Dónde está, para textos como "Supera los 15 kn en Castelldefels".
    let place: String
    let latitude: Double
    let longitude: Double
    /// Créditos que hay que mostrar (de quién son los datos y la previsión).
    let attribution: String
    let cameras: [Camera]
    let source: any StationSource

    /// Estaciones disponibles. De momento solo 17nudos.
    static let all: [Station] = [.nudos17]

    /// Clave de `UserDefaults` con el `id` de la estación elegida.
    static let selectedKey = "stationID"

    /// La elegida en los ajustes, o la primera si no hay ninguna guardada.
    /// Ojo: la complicación es otro proceso con sus propios `UserDefaults` (sin App Group,
    /// que la cuenta gratuita no permite), así que allí siempre es la primera.
    static var selected: Station {
        let id = UserDefaults.standard.string(forKey: selectedKey)
        return all.first { $0.id == id } ?? all[0]
    }
}

/// Webcam de una estación. Hoy todas son directos de YouTube incrustados con CamStreamer:
/// el reloj no puede reproducir YouTube, así que se enseña la imagen del directo
/// que publica YouTube (`hqdefault_live.jpg`), que se renueva cada pocos minutos.
struct Camera: Identifiable, Sendable {
    var id: String { name }
    var name: String
    /// Página de CamStreamer que incrusta la web; de aquí se saca el vídeo de YouTube actual.
    var embed: URL
    /// Vídeo del directo cuando se dio de alta, por si la página de CamStreamer no responde.
    var fallbackVideoID: String
    /// Web desde la que se incrusta (CamStreamer puede pedirla como `Referer`).
    var referer: URL?
}
