import SwiftUI
import BackgroundTasks
import UserNotifications

@main
struct NudosPhoneApp: App {
    @UIApplicationDelegateAdaptor private var delegate: PhoneAppDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var service = StationService()

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environment(service)
                .tint(Color("AccentColor"))  // el naranja del icono, igual que en el reloj
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { WindAlarm.scheduleBackgroundCheck() }
        }
        // con la app cerrada, iOS la despierta de vez en cuando para revisar la alarma
        .backgroundTask(.appRefresh(WindAlarm.backgroundTaskID)) {
            WindAlarm.scheduleBackgroundCheck()
            if WindAlarm.isEnabled, let r = try? await Station.selected.source.reading() {
                WindAlarm.check(r)
            }
        }
    }
}

extension WindAlarm {
    /// Tiene que coincidir con `BGTaskSchedulerPermittedIdentifiers` de `Config/NudosPhone-Info.plist`.
    static let backgroundTaskID = "com.oscarcasamitjana.nudos.viento-alarma"

    /// Pide a iOS que despierte la app para revisar la estación. Es una petición: iOS decide
    /// cuándo, según la batería y lo mucho que se use la app.
    static func scheduleBackgroundCheck() {
        guard isEnabled else { return }
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskID)
        request.earliestBeginDate = .now.addingTimeInterval(backgroundEvery)
        try? BGTaskScheduler.shared.submit(request)
    }
}

/// Muestra el aviso de viento también con la app abierta.
final class PhoneAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification)
        async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
