import SwiftUI

/// Configuración del aviso de viento.
struct AlarmSettingsView: View {
    @Environment(StationService.self) private var service
    @AppStorage(WindAlarm.enabledKey) private var enabled = false
    @AppStorage(WindAlarm.thresholdKey) private var threshold = WindAlarm.defaultThreshold
    @AppStorage(WindAlarm.metricKey) private var metricRaw = WindAlarm.Metric.racha.rawValue
    @State private var denied = false

    private var metric: WindAlarm.Metric { .init(rawValue: metricRaw) ?? .racha }

    // sin NavigationStack: el reloj la abre en una hoja y el iPhone la empuja desde Ajustes
    var body: some View {
        List {
            Section {
                Toggle("Avisar", isOn: $enabled)
                    .tint(Theme.verde)
            } footer: {
                if denied {
                    Text("Activa las notificaciones de 17nudos en la app Ajustes del \(Self.device).")
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
                     + Self.backgroundNote + " El promedio da menos avisos falsos que la racha.")
            }
        }
        .navigationTitle("Alarma")
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

    #if os(watchOS)
    private static let device = "reloj"
    private static let backgroundNote = "Con la app cerrada, el reloj revisa la estación unas 4 veces por hora "
        + "si la complicación está en la esfera."
    #else
    private static let device = "iPhone"
    private static let backgroundNote = "Con la app cerrada, iOS revisa la estación de vez en cuando "
        + "(más a menudo cuanto más uses la app); el aviso puede llegar con retraso."
    #endif
}
