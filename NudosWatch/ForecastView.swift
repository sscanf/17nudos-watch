import SwiftUI
import Charts

/// Próximas horas de la previsión de AEMET en una gráfica; al tocarla, la lista hora a hora.
struct ForecastView: View {
    @Environment(StationService.self) private var service
    @State private var showList = false

    /// Horas que caben en la gráfica sin que las flechas se amontonen.
    static let chartHours = 12

    var body: some View {
        if let f = service.forecast, !f.upcoming().isEmpty {
            let hours = f.upcoming(count: Self.chartHours)
            let top = max(hours.compactMap { $0.racha ?? $0.viento }.max() ?? 0, Theme.umbralNudos + 2)
            VStack(alignment: .leading, spacing: 2) {
                Chart {
                    ForEach(hours) { h in
                        if let g = h.racha {
                            AreaMark(x: .value("Hora", h.date), y: .value("Racha", g),
                                     series: .value("Serie", "Racha"))
                                .foregroundStyle(Theme.naranja.opacity(0.25))
                                .interpolationMethod(.monotone)
                        }
                    }
                    ForEach(hours) { h in
                        if let v = h.viento {
                            LineMark(x: .value("Hora", h.date), y: .value("Nudos", v),
                                     series: .value("Serie", "Viento"))
                                .foregroundStyle(Theme.azul)
                                .lineStyle(StrokeStyle(lineWidth: 2))
                                .interpolationMethod(.monotone)
                        }
                    }
                    // flechas de dirección cada dos horas, encima de las curvas
                    ForEach(hours.enumerated().filter { $0.offset % 2 == 0 }.map(\.element)) { h in
                        if let deg = h.grados {
                            PointMark(x: .value("Hora", h.date), y: .value("Dirección", top * 1.18))
                                .symbol {
                                    Image(systemName: "location.north.fill")
                                        .font(.system(size: 9))
                                        .foregroundStyle(Theme.viento(h.viento, base: Theme.gris))
                                        .rotationEffect(.degrees(deg + 180))
                                }
                        }
                    }
                    RuleMark(y: .value("Umbral", Theme.umbralNudos))
                        .foregroundStyle(Theme.verde.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }
                .chartYScale(domain: 0...(top * 1.3))
                .chartXScale(range: .plotDimension(padding: 6))
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 3)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.hour())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 3))
                }
                Summary(hours: hours, fuente: f.fuente)
            }
            .contentShape(Rectangle())
            .onTapGesture { showList = true }
            .sheet(isPresented: $showList) {
                ForecastList(forecast: f)
            }
        } else {
            ProgressView()
        }
    }

    /// Hora de más viento de las próximas, y la fuente (obligatorio citar a AEMET).
    private struct Summary: View {
        var hours: [Forecast.Hour]
        var fuente: String

        var body: some View {
            HStack(spacing: 4) {
                if let best = hours.max(by: { ($0.viento ?? 0) < ($1.viento ?? 0) }), let v = best.viento {
                    Text("Máx \(Optional(v).fmt(0)) kn \(best.direccion)")
                        .foregroundStyle(Theme.viento(v))
                    Text("· \(best.date.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)))) h")
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Text(fuente).foregroundStyle(.secondary)
            }
            .font(.system(size: 11, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
    }
}

/// Toda la previsión, hora a hora y agrupada por días.
struct ForecastList: View {
    var forecast: Forecast

    private var days: [(day: Date, hours: [Forecast.Hour])] {
        let cal = Calendar.current
        let groups = Dictionary(grouping: forecast.upcoming()) { cal.startOfDay(for: $0.date) }
        return groups.keys.sorted().map { ($0, groups[$0]!) }
    }

    var body: some View {
        List {
            ForEach(days, id: \.day) { day in
                Section(Self.title(day.day)) {
                    ForEach(day.hours) { HourRow(hour: $0) }
                }
            }
            Text("Previsión: \(forecast.fuente)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .listRowBackground(Color.clear)
        }
    }

    private static func title(_ day: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return "Hoy" }
        if cal.isDateInTomorrow(day) { return "Mañana" }
        return day.formatted(.dateTime.weekday(.wide)).capitalized
    }

    private struct HourRow: View {
        var hour: Forecast.Hour

        var body: some View {
            HStack(spacing: 6) {
                Text(hour.date, format: .dateTime.hour(.twoDigits(amPM: .omitted)))
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .frame(width: 26, alignment: .leading)
                Image(systemName: "location.north.fill")
                    .font(.system(size: 11))
                    .rotationEffect(.degrees((hour.grados ?? 0) + 180))
                    .opacity(hour.grados == nil ? 0 : 1)
                    .foregroundStyle(Theme.viento(hour.viento, base: Theme.gris))
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(hour.viento.fmt(0))
                            .font(.system(.body, design: .rounded).weight(.bold))
                            .foregroundStyle(Theme.viento(hour.viento))
                        Text("(\(hour.racha.fmt(0)))")
                            .font(.footnote)
                            .foregroundStyle(Theme.naranja)
                    }
                    .monospacedDigit()
                    Text(hour.direccion).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: Self.symbol(hour.cielo, night: Self.isNight(hour.date)))
                    .symbolRenderingMode(.multicolor)
                Text("\(hour.temperatura.fmt(0))°")
                    .font(.footnote)
                    .foregroundStyle(Theme.temperatura(hour.temperatura))
                    .frame(width: 28, alignment: .trailing)
            }
        }

        private static func isNight(_ date: Date) -> Bool {
            let h = Calendar.current.component(.hour, from: date)
            return h < 8 || h >= 20
        }

        /// Estado del cielo de AEMET a un símbolo del sistema.
        static func symbol(_ cielo: String, night: Bool) -> String {
            let c = cielo.lowercased()
            if c.contains("tormenta") { return "cloud.bolt.rain.fill" }
            if c.contains("nieve") { return "cloud.snow.fill" }
            if c.contains("lluvia") || c.contains("llovizna") || c.contains("chubasco") { return "cloud.rain.fill" }
            if c.contains("niebla") || c.contains("bruma") || c.contains("calima") { return "cloud.fog.fill" }
            if c.contains("despejado") { return night ? "moon.stars.fill" : "sun.max.fill" }
            if c.contains("poco nuboso") || c.contains("intervalos") || c.contains("nubes altas") {
                return night ? "cloud.moon.fill" : "cloud.sun.fill"
            }
            return "cloud.fill"
        }
    }
}

#Preview {
    ForecastView().environment(StationService.preview)
}
