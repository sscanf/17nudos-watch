import UserNotifications
import WatchKit

extension WindAlarm {
    /// Pide a watchOS que despierte la app para revisar la estación con la app cerrada.
    static func scheduleBackgroundCheck() {
        guard isEnabled else { return }
        WKApplication.shared().scheduleBackgroundRefresh(
            withPreferredDate: .now.addingTimeInterval(backgroundEvery), userInfo: nil) { _ in }
    }
}

/// Recibe las tareas en segundo plano y muestra la notificación también con la app abierta.
final class AppDelegate: NSObject, WKApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching() {
        UNUserNotificationCenter.current().delegate = self
    }

    func applicationDidEnterBackground() {
        WindAlarm.scheduleBackgroundCheck()
    }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            guard let refresh = task as? WKApplicationRefreshBackgroundTask else {
                task.setTaskCompletedWithSnapshot(false)
                continue
            }
            Task {
                if WindAlarm.isEnabled, let r = try? await Station.selected.source.reading() {
                    WindAlarm.check(r)
                }
                WindAlarm.scheduleBackgroundCheck()
                refresh.setTaskCompletedWithSnapshot(false)
            }
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification)
        async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
