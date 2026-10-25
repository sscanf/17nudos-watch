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
            .sheet(isPresented: $showAlarm) { AlarmSettingsView() }

            Text(service.station.attribution)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

/// Configuración del aviso de viento.
struct AlarmSettingsView: View {
    @Environment(StationService.self) private var service
    @AppStorage(WindAlarm.enabledKey) private var enabled = false
    @AppStorage(WindAlarm.thresholdKey) private var threshold = WindAlarm.defaultThreshold
    @AppStorage(WindAlarm.metricKey) private var metricRaw = WindAlarm.Metric.racha.rawValue
    @State private var denied = false

    private var metric: WindAlarm.Metric { .init(rawValue: metricRaw) ?? .racha }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Avisar", isOn: $enabled)
                        .tint(Theme.verde)
                } footer: {
                    if denied {
                        Text("Activa las notificaciones de 17nudos en la app Ajustes del reloj.")
                            .foregroundStyle(Theme.rojo)
                    }
                }

                Section {
                    Picker("Valor", selection: $metricRaw) {
                        ForEach(WindAlarm.Metric.allCases, id: \.self) { m in
                            Text(m.name).tag(m.rawValue)
                        }
                    }
                    Stepper(value: $threshold, in: WindAlarm.thresholdRange) {
                        Text("\(threshold) kn")
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(Theme.viento(Double(threshold)))
                    }
                } header: {
                    Text("Cuando supere")
                } footer: {
                    if let v = service.reading.flatMap(metric.value(in:)) {
                        Text("\(metric.name) ahora: \(Optional(v).fmt()) kn")
                    }
                }
                .disabled(!enabled)

                Section {
                } footer: {
                    Text("Avisa una vez; vuelve a avisar cuando baje \(Int(WindAlarm.hysteresis)) kn del umbral y lo supere otra vez. "
                         + "Con la app cerrada, el reloj revisa la estación unas 4 veces por hora si la complicación "
                         + "está en la esfera. El promedio da menos avisos falsos que la racha.")
                }
            }
            .navigationTitle("Alarma")
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
}

#Preview {
    SettingsView().environment(StationService.preview)
}

#Preview("Alarma") {
    AlarmSettingsView().environment(StationService.preview)
}
