import SwiftUI
import WidgetKit

@main
struct NudosComplicationBundle: WidgetBundle {
    var body: some Widget {
        WindComplication()
    }
}

struct WindComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WindComplication", provider: WindProvider()) { entry in
            WindComplicationView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Viento 17nudos")
        .description("Viento en directo en Castelldefels.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

// MARK: - Datos

struct WindEntry: TimelineEntry {
    var date: Date
    /// `nil` si no se ha podido conectar con la estación.
    var reading: StationReading?
}

struct WindProvider: TimelineProvider {
    /// watchOS limita cuántas veces se actualiza una complicación al día;
    /// cada 10 min es lo que se pide, el sistema decide si lo cumple.
    private let refresh: TimeInterval = 10 * 60
    private let retry: TimeInterval = 5 * 60

    func placeholder(in context: Context) -> WindEntry {
        WindEntry(date: .now, reading: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (WindEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        Task { completion(WindEntry(date: .now, reading: try? await StationAPI.reading())) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WindEntry>) -> Void) {
        Task {
            let reading = try? await StationAPI.reading()
            let next = Date.now.addingTimeInterval(reading == nil ? retry : refresh)
            completion(Timeline(entries: [WindEntry(date: .now, reading: reading)], policy: .after(next)))
        }
    }
}

// MARK: - Vistas

struct WindComplicationView: View {
    @Environment(\.widgetFamily) private var family
    var entry: WindEntry

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        case .accessoryCorner: corner
        default: inline
        }
    }

    private var r: StationReading? { entry.reading }
    private var speedColor: Color { Theme.viento(r?.actual) }

    /// Velocidad en el centro y, en el borde por donde entra el viento, un triángulo hacia el centro.
    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let g = r?.grados {
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 8))
                    .offset(y: -20)
                    .rotationEffect(.degrees(g))
                    .foregroundStyle(Theme.naranja)
                    .widgetAccentable()
            }
            VStack(spacing: -2) {
                Text(r?.actual.fmt() ?? "—")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(speedColor)
                    .widgetAccentable()
                Text(r?.direccion ?? "kn")
                    .font(.system(size: 10, weight: .semibold))
            }
            .monospacedDigit()
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 3) {
                if let g = r?.grados {
                    Image(systemName: "location.north.fill")
                        .rotationEffect(.degrees(g))  // hacia donde viene
                        .foregroundStyle(Theme.naranja)
                }
                Text(r.map { "\($0.direccion) \($0.grados.fmt(0))°" } ?? "17nudos")
                    .font(.headline)
                    .widgetAccentable()
                Spacer(minLength: 0)
                trendIcon
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(r?.actual.fmt() ?? "—")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(speedColor)
                Text("kn").font(.caption2)
                Spacer(minLength: 4)
                Text("R \(r?.racha.fmt() ?? "—")")
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.viento(r?.racha))
            }
            .monospacedDigit()
            Text(r == nil ? "Sin conexión" : "Castelldefels · \(entry.date.formatted(date: .omitted, time: .shortened))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    private var corner: some View {
        Text(r?.actual.fmt(0) ?? "—")
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .foregroundStyle(speedColor)
            .widgetCurvesContent()
            .widgetLabel {
                Text(r.map { "\($0.direccion) · R \($0.racha.fmt(0)) kn" } ?? "17nudos")
            }
    }

    private var inline: some View {
        ViewThatFits {
            Text(Image(systemName: "wind")) + Text(" \(r?.actual.fmt() ?? "—") kn \(r?.direccion ?? "") R \(r?.racha.fmt() ?? "—")")
            Text(Image(systemName: "wind")) + Text(" \(r?.actual.fmt() ?? "—") kn \(r?.direccion ?? "")")
        }
    }

    @ViewBuilder private var trendIcon: some View {
        switch r?.tendencia {
        case .subiendo: Image(systemName: "arrow.up.right").foregroundStyle(Theme.verde)
        case .bajando: Image(systemName: "arrow.down.right").foregroundStyle(Theme.azul)
        case .estable: Image(systemName: "arrow.right").foregroundStyle(Theme.gris)
        case nil: EmptyView()
        }
    }
}

#Preview(as: .accessoryRectangular) {
    WindComplication()
} timeline: {
    WindEntry(date: .now, reading: .placeholder)
    WindEntry(date: .now, reading: nil)
}

#Preview(as: .accessoryCircular) {
    WindComplication()
} timeline: {
    WindEntry(date: .now, reading: .placeholder)
}
