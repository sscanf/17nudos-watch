import SwiftUI

struct ConditionsView: View {
    @Environment(StationService.self) private var service

    // Sin ScrollView cuando cabe, por lo mismo que en WindView.
    var body: some View {
        ViewThatFits(in: .vertical) {
            content
            ScrollView { content }
        }
    }

    private var content: some View {
        let r = service.reading
        return VStack(spacing: 4) {
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
            .padding(.vertical, 4)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        }
    }
}
