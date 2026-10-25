import SwiftUI
import WebKit

/// Webcam en la pantalla principal: imagen HD del directo, renovada cada minuto.
/// Al tocarla se abre el vídeo en directo (en el iPhone sí se puede reproducir YouTube).
struct PhoneCameraCard: View {
    var camera: Camera

    @Environment(\.scenePhase) private var scenePhase
    @State private var videoID: String?
    @State private var image: UIImage?
    @State private var updated: Date?
    @State private var failed = false
    @State private var showLive = false

    private let refreshEvery: Duration = .seconds(60)

    var body: some View {
        Card(title: camera.name, subtitle: updated.map { "Imagen de las \($0.formatted(date: .omitted, time: .shortened))" }) {
            ZStack {
                Rectangle().fill(.white.opacity(0.06))
                if let image {
                    // la imagen de YouTube puede traer bandas negras: al rellenar 16:9 se recortan
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if failed {
                    Label("Cámara no disponible", systemImage: "video.slash").foregroundStyle(.secondary)
                } else {
                    ProgressView()
                }
            }
            .aspectRatio(16 / 9, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(alignment: .bottomTrailing) {
                if videoID != nil {
                    Label("En directo", systemImage: "play.fill")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.6), in: Capsule())
                        .padding(8)
                }
            }
            .onTapGesture { if videoID != nil { showLive = true } }
        }
        .fullScreenCover(isPresented: $showLive) {
            if let videoID { CameraLiveView(camera: camera, videoID: videoID) }
        }
        .task(id: scenePhase) {
            guard scenePhase == .active, !StationService.isPreview else { return }
            while !Task.isCancelled {
                await load()
                try? await Task.sleep(for: refreshEvery)
            }
        }
    }

    private func load() async {
        if videoID == nil {
            videoID = await CameraFeed.currentVideoID(for: camera) ?? camera.fallbackVideoID
        }
        guard let id = videoID else { return }
        // la HD no siempre existe en un directo: si no, la miniatura
        var img = await CameraFeed.liveImage(videoID: id, quality: .hd)
        if img == nil { img = await CameraFeed.liveImage(videoID: id, quality: .thumbnail) }
        if let img {
            image = img
            updated = .now
            failed = false
        } else {
            // puede que el directo se haya reiniciado con otro vídeo: se vuelve a buscar
            videoID = nil
            failed = image == nil
        }
    }
}

/// Vídeo en directo a pantalla completa (se puede girar el iPhone para verlo apaisado).
private struct CameraLiveView: View {
    var camera: Camera
    var videoID: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()
            YouTubePlayer(videoID: videoID, origin: camera.referer)
                .aspectRatio(16 / 9, contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .padding(10)
                        .background(.white.opacity(0.15), in: Circle())
                }
                Spacer()
                Text(camera.name).font(.headline)
                Spacer()
                // por si el reproductor incrustado no funciona: la app o la web de YouTube
                Link(destination: URL(string: "https://www.youtube.com/watch?v=\(videoID)")!) {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.headline)
                        .padding(10)
                        .background(.white.opacity(0.15), in: Circle())
                }
            }
            .foregroundStyle(.white)
            .padding()
        }
    }
}

/// Reproductor de YouTube incrustado. Se carga como si estuviera en la web de la estación
/// (`origin`): YouTube no reproduce vídeos incrustados en páginas sin origen.
private struct YouTubePlayer: UIViewRepresentable {
    var videoID: String
    var origin: URL?

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let view = WKWebView(frame: .zero, configuration: config)
        view.isOpaque = false
        view.backgroundColor = .black
        view.scrollView.isScrollEnabled = false
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        guard context.coordinator.loaded != videoID else { return }
        context.coordinator.loaded = videoID
        let html = """
            <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
            <style>html,body{margin:0;height:100%;background:#000}iframe{position:absolute;inset:0;width:100%;height:100%;border:0}</style>
            </head><body>
            <iframe src="https://www.youtube.com/embed/\(videoID)?autoplay=1&mute=1&playsinline=1&rel=0"
                    allow="autoplay; encrypted-media; picture-in-picture; fullscreen" allowfullscreen></iframe>
            </body></html>
            """
        view.loadHTMLString(html, baseURL: origin ?? URL(string: "https://www.youtube.com/"))
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var loaded: String?
    }
}
