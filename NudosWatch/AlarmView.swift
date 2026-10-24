import SwiftUI

/// Configurar el aviso de viento. Sin corona: dentro del TabView de páginas la corona pasa de página.
struct AlarmView: View {
    @Environment(StationService.self) private var service
    @AppStorage(WindAlarm.enabledKey) private var enabled = false
    @AppStorage(WindAlarm.thresholdKey) private var threshold = WindAlarm.defaultThreshold
    @AppStorage(WindAlarm.metricKey) private var metricRaw = WindAlarm.Metric.racha.rawValue
    @State private var denied = false

    private var metric: WindAlarm.Metric { .init(rawValue: metricRaw) ?? .racha }

    var body: some View {
        VStack(spacing: 6) {
            Toggle(isOn: $enabled) {
                Label("Avisar", systemImage: enabled ? "bell.fill" : "bell.slash")
            }
            .tint(Theme.verde)

            Button { metricRaw = next(metric).rawValue } label: {
                HStack {
                    Text(metric.name).font(.headline)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 4) {
                Button { threshold = max(WindAlarm.thresholdRange.lowerBound, threshold - 1) } label: {
                    Image(systemName: "minus")
                }
                .frame(width: 50)
                Text("≥ \(threshold) kn")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.viento(Double(threshold)))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
                Button { threshold = min(WindAlarm.thresholdRange.upperBound, threshold + 1) } label: {
                    Image(systemName: "plus")
                }
                .frame(width: 50)
            }

            status
        }
        .onChange(of: enabled) { _, on in
            WindAlarm.rearm()
            guard on else { return }
            Task {
                denied = !(await WindAlarm.requestPermission())
                if let r = service.reading { WindAlarm.check(r) }
            }
        }
        .onChange(of: threshold) { WindAlarm.rearm() }
        .onChange(of: metricRaw) { WindAlarm.rearm() }
    }

    @ViewBuilder private var status: some View {
        Group {
            if denied {
                Text("Activa las notificaciones de 17nudos en Ajustes")
                    .foregroundStyle(Theme.rojo)
            } else if let v = service.reading.flatMap(metric.value(in:)) {
                Text("\(metric.name) ahora: \(Optional(v).fmt()) kn")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption2)
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .minimumScaleFactor(0.8)
    }

    private func next(_ m: WindAlarm.Metric) -> WindAlarm.Metric {
        let all = WindAlarm.Metric.allCases
        return all[(all.firstIndex(of: m)! + 1) % all.count]
    }
}

#Preview {
    AlarmView().environment(StationService.preview)
}
