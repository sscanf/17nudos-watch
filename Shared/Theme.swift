import SwiftUI

/// Colores y umbrales de la web de 17nudos.
enum Theme {
    static let verde = Color(red: 0x3F / 255, green: 0xD4 / 255, blue: 0x7A / 255)
    static let naranja = Color(red: 0xF5 / 255, green: 0x8A / 255, blue: 0x4E / 255)
    static let azul = Color(red: 0x5C / 255, green: 0xC8 / 255, blue: 0xE8 / 255)
    static let rojo = Color(red: 0xFF / 255, green: 0x5A / 255, blue: 0x5F / 255)
    static let gris = Color(red: 0xC9 / 255, green: 0xD8 / 255, blue: 0xE1 / 255)

    /// Por encima de 8 nudos la web pinta el viento en verde (se puede navegar).
    static let umbralNudos = 8.0

    static func viento(_ v: Double?, base: Color = naranja) -> Color {
        guard let v else { return .secondary }
        return v > umbralNudos ? verde : base
    }

    static func temperatura(_ t: Double?) -> Color {
        guard let t else { return .secondary }
        if t < 15 { return azul }
        if t > 25 { return rojo }
        return .primary
    }
}

extension Optional where Wrapped == Double {
    func fmt(_ digits: Int = 1) -> String {
        guard let v = self else { return "—" }
        return v.formatted(.number.precision(.fractionLength(digits)))
    }
}
