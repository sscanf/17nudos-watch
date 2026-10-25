import SwiftUI

/// Pantalla única del iPhone: todo lo de la estación de un vistazo, deslizando hacia abajo.
struct DashboardView: View {
    @Environment(StationService.self) private var service
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSettings = false

    /// Igual que en el reloj: la web refresca cada 5 s, aquí basta con algo más espaciado.
    private let refreshEvery: Duration = .seconds(15)

    var body: some View {
        let station = service.station
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    WindCard()
                    ConditionsCard()
                    if station.source.hasHistory {
                        Card(title: "Últimas \(StationService.historyHours) h") {
                            HistoryChartView().frame(height: 200)
                        }
                    }
                    if station.source.hasForecast {
                        Card(title: "Previsión", subtitle: "Toca para ver hora a hora") {
                            ForecastView().frame(height: 210)
                        }
                    }
                    ForEach(station.cameras) { cam in
                        PhoneCameraCard(camera: cam)
                    }
                    Text(station.attribution)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .background(Color.black)
            .refreshable { await service.refresh() }
            .navigationTitle(station.name)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                }
            }
            .sheet(isPresented: $showSettings) { PhoneSettingsView() }
        }
        .preferredColorScheme(.dark)
        .task(id: scenePhase) {
            guard !StationService.isPreview, scenePhase == .active else { return }
            var tick = 0
            while !Task.isCancelled {
                // la gráfica cambia por minutos: se pide una vez de cada cuatro
                await service.refresh(includeHistory: tick % 4 == 0)
                tick += 1
                try? await Task.sleep(for: refreshEvery)
            }
        }
    }
}

/// Tarjeta con título, el bloque que agrupa cada sección de la pantalla.
struct Card<Content: View>: View {
    var title: String
    var subtitle: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.headline).foregroundStyle(.tint)
                Spacer()
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
    }
}

/// Viento en directo: brújula de precisión, velocidad grande, promedio, racha y tendencia.
private struct WindCard: View {
    @Environment(StationService.self) private var service

    var body: some View {
        let r = service.reading
        let spread = service.history?.directionSpread()
        VStack(spacing: 14) {
            PrecisionCompass(degrees: r?.grados, spread: spread) { k in
                VStack(spacing: -2 * k) {
                    Text("\(r?.grados.fmt(0) ?? "—")°")
                        .font(.system(size: 24 * k, weight: .bold, design: .rounded))
                    Text(r?.direccion ?? "")
                        .font(.system(size: 12 * k, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .monospacedDigit()
            }
            .frame(maxWidth: 340)

            HStack(alignment: .center, spacing: 16) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(r?.actual.fmt() ?? "—")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("kn").font(.title3)
                }
                .foregroundStyle(Theme.viento(r?.actual))
                VStack(alignment: .leading, spacing: 2) {
                    if let r {
                        Text("\(r.direccion) · \(r.grados.fmt(0))°").font(.headline)
                        if !r.nombre.isEmpty {
                            Text(r.nombre.capitalized).foregroundStyle(.secondary)
                        }
                    }
                    if let spread {
                        Text("15′ \(directionRangeText(spread))")
                            .font(.subheadline)
                            .foregroundStyle(Theme.naranja)
                    }
                }
                .lineLimit(1)
            }

            HStack(spacing: 8) {
                StatTile(title: "Promedio", value: r?.promedio, color: Theme.viento(r?.promedio, base: Theme.azul))
                StatTile(title: "Racha", value: r?.racha, color: Theme.viento(r?.racha))
                StatTile(title: "Media 15′", value: r?.media15, color: Theme.viento(r?.media15, base: Theme.azul))
                StatTile(title: "Máx 15′", value: r?.rachamax15, color: Theme.viento(r?.rachamax15))
            }

            if let e = service.error {
                Label(e, systemImage: "wifi.exclamationmark").foregroundStyle(Theme.rojo)
            } else if let r {
                TrendLine(reading: r)
            } else {
                ProgressView("Conectando…")
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct StatTile: View {
    var title: String
    var value: Double?
    var color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            Text(value.fmt())
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct TrendLine: View {
    var reading: StationReading

    var body: some View {
        HStack(spacing: 6) {
            switch reading.tendencia {
            case .subiendo: Label("Subiendo", systemImage: "arrow.up.right")
            case .bajando: Label("Bajando", systemImage: "arrow.down.right")
            case .estable: Label("Estable", systemImage: "arrow.right")
            case nil: Text("Calculando tendencia…")
            }
            if let d = reading.delta, reading.tendencia != nil {
                Text("\(d > 0 ? "+" : "")\(d.formatted(.number.precision(.fractionLength(1)))) kn en 15′")
                    .foregroundStyle(.secondary)
            }
            if reading.racheado {
                Text("Racheado")
                    .font(.caption.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.naranja.opacity(0.3), in: Capsule())
            }
        }
        .font(.subheadline)
        .foregroundStyle(color)
    }

    private var color: Color {
        switch reading.tendencia {
        case .subiendo: Theme.verde
        case .bajando: Theme.azul
        default: Theme.gris
        }
    }
}

private struct ConditionsCard: View {
    @Environment(StationService.self) private var service

    var body: some View {
        let r = service.reading
        Card(title: "Condiciones") {
            HStack(spacing: 8) {
                Condition(icon: "thermometer.medium", value: "\(r?.temperatura.fmt() ?? "—") °C",
                          color: Theme.temperatura(r?.temperatura))
                Condition(icon: "humidity", value: "\(r?.humedad.fmt(0) ?? "—") %")
                Condition(icon: "gauge.with.dots.needle.33percent", value: "\(r?.presion.fmt(0) ?? "—") hPa")
            }
        }
    }

    private struct Condition: View {
        var icon: String
        var value: String
        var color: Color = .primary

        var body: some View {
            VStack(spacing: 4) {
                Image(systemName: icon).foregroundStyle(.secondary)
                Text(value)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    DashboardView().environment(StationService.preview)
}
