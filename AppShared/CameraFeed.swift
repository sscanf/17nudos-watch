import Foundation
import UIKit

/// Descarga de las webcams: el vídeo de YouTube que hay ahora en el directo y su imagen.
enum CameraFeed {
    /// El directo de YouTube cambia de vídeo si se reinicia: se lee de la página de CamStreamer.
    static func currentVideoID(for camera: Camera) async -> String? {
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
        /// 1280×720, ~150 KB
        case hd = "maxresdefault_live"
    }

    static func liveImage(videoID: String, quality: Quality) async -> UIImage? {
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
