import SwiftUI

struct ConditionsView: View {
    @Environment(StationService.self) private var service

    var body: some View {
        let r = service.reading
        ScrollView {
            VStack(spacing: 6) {
                Row(icon: "thermometer.medium", title: "Temperatura",
                    value: "\(r?.temperatura.fmt() ?? "—") °C",
                    color: Theme.temperatura(r?.temperatura))
                Row(icon: "humidity", title: "Humedad",
                    value: "\(r?.humedad.fmt(0) ?? "—") %")
                Row(icon: "gauge.with.dots.needle.33percent", title: "Presión",
                    value: "\(r?.presion.fmt() ?? "—") hPa")
                HStack(spacing: 6) {
                    Tile(title: "Media 15′", value: (r?.media15).fmt(), unit: "kn",
                         color: Theme.viento(r?.media15, base: Theme.azul))
                    Tile(title: "Máx 15′", value: (r?.rachamax15).fmt(), unit: "kn",
                         color: Theme.viento(r?.rachamax15))
                }
            }
        }
        // si cabe en pantalla no hay desplazamiento: un gesto pasa de página
        .scrollBounceBehavior(.basedOnSize)
    }

    private struct Row: View {
        var icon: String
        var title: String
        var value: String
        var color: Color = .primary

        var body: some View {
            HStack {
                Image(systemName: icon)
                    .frame(width: 20)
                    .foregroundStyle(.secondary)
                Text(title).font(.footnote)
                Spacer()
                Text(value)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(color)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        }
    }
}
