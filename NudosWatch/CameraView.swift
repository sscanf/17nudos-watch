import SwiftUI
import UIKit

struct CameraView: View {
    var camera: Camera

    @Environment(\.scenePhase) private var scenePhase
    @State private var videoID: String?
    @State private var image: UIImage?
    @State private var updated: Date?
    @State private var failed = false
    @State private var showZoom = false

    private let refreshEvery: Duration = .seconds(60)

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.08))
                if let image {
                    // la imagen de YouTube es 4:3 con bandas negras: al rellenar 16:9 se recortan
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if failed {
                    Image(systemName: "video.slash").foregroundStyle(.secondary)
                } else {
                    ProgressView()
                }
            }
            .aspectRatio(16 / 9, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(alignment: .bottomTrailing) {
                if image != nil {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 10, weight: .bold))
                        .padding(4)
                        .background(.black.opacity(0.5), in: Circle())
                        .padding(4)
                }
            }
            .onTapGesture { if image != nil { showZoom = true } }
            .sheet(isPresented: $showZoom) {
                CameraZoomView(camera: camera, videoID: videoID, thumbnail: image)
            }

            Text(camera.name)
                .font(.footnote.weight(.semibold))
            Group {
                if let updated {
                    Text("Descargada \(updated.formatted(date: .omitted, time: .shortened))")
                } else if failed {
                    Text("Cámara no disponible")
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
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
            videoID = await Self.currentVideoID(for: camera) ?? camera.fallbackVideoID
        }
        guard let id = videoID else { return }
        if let img = await Self.liveImage(videoID: id, quality: .thumbnail) {
            image = img
            updated = .now
            failed = false
        } else {
            // puede que el directo se haya reiniciado con otro vídeo: se vuelve a buscar
            videoID = nil
            failed = image == nil
        }
    }

    fileprivate static func currentVideoID(for camera: Camera) async -> String? {
        var req = URLRequest(url: camera.embed)
        if let referer = camera.referer {
            req.setValue(referer.absoluteString, forHTTPHeaderField: "Referer")
        }
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let html = String(data: data, encoding: .utf8),
              let m = html.firstMatch(of: #/youtube\.com/embed/([A-Za-z0-9_-]{11})/#)
        else { return nil }
        return String(m.1)
    }

    enum Quality: String {
        /// 480×360 (16:9 con bandas negras), ~15 KB
        case thumbnail = "hqdefault_live"
        /// 1280×720, ~150 KB: solo para la vista ampliada
        case hd = "maxresdefault_live"
    }

    fileprivate static func liveImage(videoID: String, quality: Quality) async -> UIImage? {
        let ts = Int(Date().timeIntervalSince1970)
        guard let url = URL(string: "https://i.ytimg.com/vi/\(videoID)/\(quality.rawValue).jpg?t=\(ts)") else { return nil }
        var req = URLRequest(url: url)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        return UIImage(data: data)
    }
}

/// Imagen de la cámara a pantalla completa en HD.
/// watchOS no tiene pellizcar: se amplía con la corona y se mueve arrastrando;
/// doble toque alterna entre imagen entera y 2,5×.
private struct CameraZoomView: View {
    var camera: Camera
    var videoID: String?
    var thumbnail: UIImage?

    @State private var hd: UIImage?
    @State private var zoom = 1.0
    @State private var offset = CGSize.zero
    @State private var dragStart = CGSize.zero
    @State private var showZoomLevel = false

    private let maxZoom = 5.0

    var body: some View {
        GeometryReader { geo in
            let img = hd ?? thumbnail
            let fitted = fittedSize(in: geo.size)
            ZStack {
                Color.black
                if let img {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: fitted.width, height: fitted.height)
                        .clipped()  // la miniatura trae bandas negras: se recortan a 16:9
                        .scaleEffect(zoom)
                        .offset(offset)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { v in
                        offset = clamp(CGSize(width: dragStart.width + v.translation.width,
                                              height: dragStart.height + v.translation.height),
                                       fitted: fitted, view: geo.size)
                    }
                    .onEnded { _ in dragStart = offset }
            )
            .onTapGesture(count: 2) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    zoom = zoom > 1.01 ? 1 : 2.5
                    offset = clamp(offset, fitted: fitted, view: geo.size)
                    dragStart = offset
                }
            }
            .onChange(of: zoom) { _, _ in
                showZoomLevel = true
                offset = clamp(offset, fitted: fitted, view: geo.size)
                dragStart = offset
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .focusable()
        .digitalCrownRotation($zoom, from: 1, through: maxZoom, by: 0.1,
                              sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
        // Nada fijo encima de la imagen: solo un indicador pequeño mientras llega
        // la HD y el nivel de zoom un momento después de girar la corona.
        .overlay(alignment: .bottomTrailing) {
            Group {
                if hd == nil {
                    ProgressView().frame(width: 14, height: 14)
                } else if showZoomLevel {
                    Text(zoom.formatted(.number.precision(.fractionLength(1))) + "×")
                        .font(.caption2)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.black.opacity(0.6), in: Capsule())
            .opacity(hd == nil || showZoomLevel ? 1 : 0)
            .padding(6)
        }
        .task(id: zoom) {
            guard showZoomLevel else { return }
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation { showZoomLevel = false }
        }
        .task {
            guard !StationService.isPreview else { return }
            let id: String? = if let videoID { videoID } else { await CameraView.currentVideoID(for: camera) }
            if let id { hd = await CameraView.liveImage(videoID: id, quality: .hd) }
        }
    }

    /// Tamaño de la imagen 16:9 encajada a lo ancho de la pantalla con zoom 1.
    private func fittedSize(in view: CGSize) -> CGSize {
        let w = view.width
        return CGSize(width: w, height: w * 9 / 16)
    }

    /// Impide arrastrar la imagen más allá de sus bordes.
    private func clamp(_ o: CGSize, fitted: CGSize, view: CGSize) -> CGSize {
        let maxX = max(0, (fitted.width * zoom - view.width) / 2)
        let maxY = max(0, (fitted.height * zoom - view.height) / 2)
        return CGSize(width: min(max(o.width, -maxX), maxX),
                      height: min(max(o.height, -maxY), maxY))
    }
}

#Preview {
    CameraView(camera: Station.nudos17.cameras[0])
}
