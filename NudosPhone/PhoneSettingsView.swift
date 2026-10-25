import SwiftUI

/// Ajustes del iPhone: la estación y la alarma de viento.
struct PhoneSettingsView: View {
    @Environment(StationService.self) private var service
    @Environment(\.dismiss) private var dismiss
    @AppStorage(WindAlarm.enabledKey) private var alarmOn = false
    @AppStorage(WindAlarm.thresholdKey) private var threshold = WindAlarm.defaultThreshold
    @AppStorage(WindAlarm.metricKey) private var metricRaw = WindAlarm.Metric.racha.rawValue

    var body: some View {
        let station = service.station
        NavigationStack {
            List {
                Section {
                    LabeledContent("Estación", value: station.name)
                    LabeledContent("Lugar", value: station.place)
                } header: {
                    Text("Estación")
                } footer: {
                    Text(station.attribution)
                }

                Section {
                    NavigationLink {
                        AlarmSettingsView()
                    } label: {
                        HStack {
                            Label("Alarma de viento", systemImage: alarmOn ? "bell.fill" : "bell.slash")
                            Spacer()
                            Text(alarmOn ? "\(WindAlarm.Metric(rawValue: metricRaw)?.name ?? "") ≥ \(threshold) kn"
                                         : "Desactivada")
                                .foregroundStyle(alarmOn ? Theme.verde : .secondary)
                        }
                    }
                }
            }
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hecho") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    PhoneSettingsView().environment(StationService.preview)
}
