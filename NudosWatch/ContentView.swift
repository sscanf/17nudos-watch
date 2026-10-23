import SwiftUI
import WidgetKit

struct ContentView: View {
    @Environment(StationService.self) private var service
    @Environment(\.scenePhase) private var scenePhase

    /// La web refresca cada 5 s; en el reloj basta con algo más espaciado.
    private let refreshEvery: Duration = .seconds(15)

    // Sin NavigationStack: la app no navega a ningún sitio, y la barra de
    // navegación con un título por página hacía caer las previews de Xcode.
    var body: some View {
        TabView {
            Page(title: "17nudos") { WindView() }
            Page(title: "Condiciones") { ConditionsView() }
            Page(title: "Últimas \(StationService.historyHours) h") { HistoryChartView() }
            ForEach(Camera.all) { cam in
                Page(title: "Cámara") { CameraView(camera: cam) }
            }
        }
        .tabViewStyle(.verticalPage)
        .task(id: scenePhase) {
            guard !StationService.isPreview else { return }
            guard scenePhase == .active else {
                // al salir de la app, la complicación se pone al día con lo último
                WidgetCenter.shared.reloadAllTimelines()
                return
            }
            var tick = 0
            while !Task.isCancelled {
                // la gráfica cambia por minutos: se pide una vez de cada cuatro
                await service.refresh(includeHistory: tick % 4 == 0)
                tick += 1
                try? await Task.sleep(for: refreshEvery)
            }
        }
    }
}

/// Página con su título como cabecera.
private struct Page<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.tint)
                .padding(.leading, 4)
            content
                .frame(maxHeight: .infinity, alignment: .top)
        }
    }
}

#Preview("Con datos") {
    ContentView().environment(StationService.preview)
}

#Preview("Cargando") {
    ContentView().environment(StationService())
}
