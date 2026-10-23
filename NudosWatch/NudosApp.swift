import SwiftUI

@main
struct NudosApp: App {
    @State private var service = StationService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(service)
        }
    }
}
