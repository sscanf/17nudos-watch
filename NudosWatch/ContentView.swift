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
            Page(title: "17nudos", useBottomInset: true) { WindView() }
            Page(title: "Condiciones", useBottomInset: true) { ConditionsView() }
            Page(title: "Últimas \(StationService.historyHours) h") { HistoryChartView() }
            Page(title: "Previsión") { ForecastView() }
            Page(title: "Alarma", useBottomInset: true) { AlarmView() }
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
    /// El TabView de páginas reserva ~39 pt abajo que en pantalla están vacíos. Si el
    /// contenido no cabe en lo que queda, watchOS desplaza la página antes de pasar a la
    /// siguiente (dos gestos). Las páginas de texto usan también esa franja.
    var useBottomInset = false
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
        .ignoresSafeArea(.container, edges: useBottomInset ? .bottom : [])
    }
}

#Preview("Con datos") {
    ContentView().environment(StationService.preview)
}

#Preview("Cargando") {
    ContentView().environment(StationService())
}
