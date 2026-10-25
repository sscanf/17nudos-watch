import SwiftUI

/// Última página: ajustes de la app. Cada fila abre su pantalla, que sí puede desplazarse.
struct SettingsView: View {
    @Environment(StationService.self) private var service
    @AppStorage(WindAlarm.enabledKey) private var alarmOn = false
    @AppStorage(WindAlarm.thresholdKey) private var threshold = WindAlarm.defaultThreshold
    @AppStorage(WindAlarm.metricKey) private var metricRaw = WindAlarm.Metric.racha.rawValue
    @State private var showAlarm = false

    var body: some View {
        VStack(spacing: 8) {
            Button { showAlarm = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: alarmOn ? "bell.fill" : "bell.slash")
                        .foregroundStyle(alarmOn ? Theme.verde : .secondary)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Alarma de viento").font(.headline)
                        Text(alarmOn ? "\(WindAlarm.Metric(rawValue: metricRaw)?.name ?? "") ≥ \(threshold) kn"
                                     : "Desactivada")
                            .font(.footnote)
                            .foregroundStyle(alarmOn ? Theme.verde : .secondary)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .sheet(isPresented: $showAlarm) {
                NavigationStack { AlarmSettingsView() }
            }

            Text(service.station.attribution)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    SettingsView().environment(StationService.preview)
}

#Preview("Alarma") {
    NavigationStack { AlarmSettingsView() }.environment(StationService.preview)
}
