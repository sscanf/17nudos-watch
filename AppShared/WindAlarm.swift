import Foundation
import UserNotifications

/// Aviso cuando el viento supera un umbral. Se comprueba con cada lectura mientras la app
/// está abierta y, con la app cerrada, en las actualizaciones en segundo plano del sistema
/// (cada plataforma programa las suyas: `AppDelegate` en el reloj, `NudosPhoneApp` en el iPhone).
enum WindAlarm {
    enum Metric: String, CaseIterable {
        case racha, promedio, actual

        var name: String {
            switch self {
            case .racha: "Racha"
            case .promedio: "Promedio"
            case .actual: "Actual"
            }
        }

        func value(in r: StationReading) -> Double? {
            switch self {
            case .racha: r.racha
            case .promedio: r.promedio
            case .actual: r.actual
            }
        }
    }

    // claves de UserDefaults, también usadas por @AppStorage en AlarmView
    static let enabledKey = "alarmEnabled"
    static let thresholdKey = "alarmThreshold"
    static let metricKey = "alarmMetric"
    private static let armedKey = "alarmArmed"

    static let defaultThreshold = 15
    static let thresholdRange = 5...40
    /// Tiene que bajar esto por debajo del umbral para volver a avisar (evita avisos en ráfaga).
    static let hysteresis = 2.0
    /// Cada cuánto se pide revisar en segundo plano. Es un mínimo: el sistema decide
    /// (watchOS da unas 4 por hora si la complicación está en la esfera; iOS, según el uso).
    static let backgroundEvery: TimeInterval = 15 * 60

    private static var defaults: UserDefaults { .standard }

    static var isEnabled: Bool { defaults.bool(forKey: enabledKey) }

    static var threshold: Double {
        let t = defaults.integer(forKey: thresholdKey)
        return Double(t == 0 ? defaultThreshold : t)
    }

    static var metric: Metric {
        defaults.string(forKey: metricKey).flatMap(Metric.init(rawValue:)) ?? .racha
    }

    /// Se vuelve a armar al cambiar la configuración, para que avise si ya se cumple.
    static func rearm() {
        defaults.set(true, forKey: armedKey)
    }

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func check(_ r: StationReading) {
        guard isEnabled, let v = metric.value(in: r) else { return }
        let armed = defaults.object(forKey: armedKey) as? Bool ?? true
        if armed, v >= threshold {
            defaults.set(false, forKey: armedKey)
            notify(value: v, reading: r)
        } else if !armed, v < threshold - hysteresis {
            defaults.set(true, forKey: armedKey)
        }
    }

    private static func notify(value: Double, reading r: StationReading) {
        let content = UNMutableNotificationContent()
        content.title = "\(metric.name) \(Optional(value).fmt()) kn \(r.direccion)"
        content.body = "Supera los \(Int(threshold)) kn en \(Station.selected.place). "
            + "Promedio \(r.promedio.fmt()) · racha \(r.racha.fmt()) kn"
        content.sound = .default
        let request = UNNotificationRequest(identifier: "viento", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
