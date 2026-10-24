import SwiftUI

@main
struct NudosApp: App {
    @WKApplicationDelegateAdaptor private var delegate: AppDelegate
    @State private var service = StationService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(service)
        }
    }
}
