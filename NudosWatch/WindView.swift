import SwiftUI

struct WindView: View {
    @Environment(StationService.self) private var service

    var body: some View {
        // El ScrollView existe desde el principio y solo cambia su contenido,
        // para no insertar una vista desplazable a mitad de maquetación.
        ScrollView {
            if let r = service.reading {
                VStack(spacing: 6) {
                    HStack(alignment: .center, spacing: 8) {
                        CompassView(degrees: r.grados)
                            .frame(width: 64, height: 64)
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text(r.actual.fmt())
                                    .font(.system(size: 40, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .minimumScaleFactor(0.6)
                                Text("kn").font(.footnote)
                            }
                            .foregroundStyle(Theme.viento(r.actual))
                            Text("\(r.direccion) · \(r.grados.fmt(0))°")
                                .font(.footnote.weight(.semibold))
                            if !r.nombre.isEmpty {
                                Text(r.nombre.capitalized)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .lineLimit(1)
                    }

                    HStack(spacing: 6) {
                        Tile(title: "Promedio", value: r.promedio.fmt(), unit: "kn",
                             color: Theme.viento(r.promedio, base: Theme.azul))
                        Tile(title: "Racha", value: r.racha.fmt(), unit: "kn",
                             color: Theme.viento(r.racha))
                    }

                    // Una sola línea al final: así la página cabe entera en la pantalla
                    // y un solo gesto pasa a la siguiente, sin desplazamiento previo.
                    if let e = service.error {
                        Label(e, systemImage: "wifi.exclamationmark")
                            .font(.caption2)
                            .foregroundStyle(Theme.rojo)
                    } else {
                        TrendRow(reading: r)
                    }
                }
            } else if let e = service.error {
                VStack(spacing: 8) {
                    Label(e, systemImage: "wifi.exclamationmark")
                        .multilineTextAlignment(.center)
                    Button("Reintentar") { Task { await service.refresh() } }
                }
            } else {
                ProgressView("Conectando…")
                    .padding(.top, 30)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

struct Tile: View {
    var title: String
    var value: String
    var unit: String
    var color: Color = .primary

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value)
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                Text(unit).font(.system(size: 10))
            }
            .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct TrendRow: View {
    var reading: StationReading

    var body: some View {
        HStack(spacing: 4) {
            switch reading.tendencia {
            case .subiendo:
                Image(systemName: "arrow.up.right")
                Text("Subiendo")
            case .bajando:
                Image(systemName: "arrow.down.right")
                Text("Bajando")
            case .estable:
                Image(systemName: "arrow.right")
                Text("Estable")
            case nil:
                Text("Calculando tendencia…")
            }
            if let d = reading.delta, reading.tendencia != nil {
                Text("\(d > 0 ? "+" : "")\(d.formatted(.number.precision(.fractionLength(1)))) kn/15′")
                    .foregroundStyle(.secondary)
            }
            if reading.racheado {
                Text("Racheado")
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 4)
                    .background(Theme.naranja.opacity(0.3), in: Capsule())
            }
        }
        .font(.caption2)
        .foregroundStyle(color)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    private var color: Color {
        switch reading.tendencia {
        case .subiendo: Theme.verde
        case .bajando: Theme.azul
        default: Theme.gris
        }
    }
}

/// Rosa de los vientos con una flecha que indica hacia dónde sopla el viento
/// (igual que las flechas de la gráfica de la web).
struct CompassView: View {
    var degrees: Double?

    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.25), lineWidth: 2)
            ForEach(Array(["N", "E", "S", "W"].enumerated()), id: \.offset) { i, l in
                Text(l)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(l == "N" ? Theme.naranja : .secondary)
                    .offset(y: -24)
                    .rotationEffect(.degrees(Double(i) * 90))
            }
            if let degrees {
                Image(systemName: "location.north.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.naranja)
                    .rotationEffect(.degrees(degrees + 180))
                    .animation(.easeInOut, value: degrees)
            }
        }
    }
}
