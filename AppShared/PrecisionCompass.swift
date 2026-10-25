import SwiftUI

/// Hacia dónde ha oscilado el viento: dirección media y separación a cada lado (grados).
typealias DirectionSpread = (mean: Double, left: Double, right: Double)

/// "205°–240°": entre qué rumbos ha venido el viento.
func directionRangeText(_ s: DirectionSpread) -> String {
    func norm(_ d: Double) -> Int { Int((d + 360).truncatingRemainder(dividingBy: 360).rounded()) }
    return "\(norm(s.mean - s.left))°–\(norm(s.mean + s.right))°"
}

/// Brújula de precisión: marcas cada 5°, números cada 30° (los cardinales con letra),
/// arco naranja con la variación reciente y aguja que apunta hacia donde viene el viento.
/// Está dibujada para 205 pt (el ancho del Ultra 2) y todo escala con el tamaño que se le dé;
/// `center` recibe esa escala para el círculo central.
struct PrecisionCompass<Center: View>: View {
    var degrees: Double?
    var spread: DirectionSpread?
    @ViewBuilder var center: (_ scale: CGFloat) -> Center

    var body: some View {
        GeometryReader { geo in
            let k = min(geo.size.width, geo.size.height) / 205
            ZStack {
                Dial(spread: spread, k: k)
                if let degrees {
                    ZStack {
                        Needle(head: false, width: 6 * k).fill(.white.opacity(0.5))
                        Needle(head: true, width: 6 * k).fill(Theme.naranja)
                    }
                    .padding(14 * k)
                    .rotationEffect(.degrees(degrees))  // hacia donde viene
                    .animation(.easeInOut, value: degrees)
                }
                // centro: tapa el pie de la aguja
                center(k)
                    .frame(width: 72 * k, height: 72 * k)
                    .background(.black, in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private struct Dial: View {
        var spread: DirectionSpread?
        var k: CGFloat

        var body: some View {
            GeometryReader { geo in
                let radius = min(geo.size.width, geo.size.height) / 2
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                ZStack {
                    if let spread {
                        // al menos unos grados para que se vea aunque el viento esté muy estable
                        let left = max(spread.left, 3), right = max(spread.right, 3)
                        Path { p in
                            p.addArc(center: center, radius: radius - 6 * k,
                                     startAngle: .degrees(spread.mean - left - 90),
                                     endAngle: .degrees(spread.mean + right - 90), clockwise: false)
                        }
                        .stroke(Theme.naranja.opacity(0.45), style: StrokeStyle(lineWidth: 12 * k, lineCap: .butt))
                    }
                    Canvas { ctx, _ in
                        for deg in stride(from: 0, to: 360, by: 5) {
                            let len: CGFloat = (deg % 30 == 0 ? 11 : deg % 10 == 0 ? 7 : 4) * k
                            let a = Double(deg - 90) * .pi / 180
                            var tick = Path()
                            tick.move(to: CGPoint(x: center.x + cos(a) * radius, y: center.y + sin(a) * radius))
                            tick.addLine(to: CGPoint(x: center.x + cos(a) * (radius - len),
                                                     y: center.y + sin(a) * (radius - len)))
                            ctx.stroke(tick, with: .color(.white.opacity(deg % 10 == 0 ? 0.8 : 0.4)),
                                       lineWidth: (deg % 30 == 0 ? 2 : 1) * max(1, k * 0.8))
                        }
                    }
                    ForEach(Array(stride(from: 0, to: 360, by: 30)), id: \.self) { deg in
                        Label(deg: deg, k: k)
                            .position(x: center.x + sin(Double(deg) * .pi / 180) * (radius - 24 * k),
                                      y: center.y - cos(Double(deg) * .pi / 180) * (radius - 24 * k))
                    }
                }
            }
        }

        private struct Label: View {
            var deg: Int
            var k: CGFloat
            private static var cardinals: [Int: String] { [0: "N", 90: "E", 180: "S", 270: "W"] }

            var body: some View {
                if let c = Self.cardinals[deg] {
                    Text(c)
                        .font(.system(size: 18 * k, weight: .heavy))
                        .foregroundStyle(deg == 0 ? Theme.naranja : .white)
                } else {
                    Text("\(deg)")
                        .font(.system(size: 12 * k, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// Aguja fina: la punta (hacia arriba, luego se gira) o la cola, más corta.
    private struct Needle: Shape {
        var head: Bool
        var width: CGFloat

        func path(in rect: CGRect) -> Path {
            let c = CGPoint(x: rect.midX, y: rect.midY)
            let half = min(rect.width, rect.height) / 2
            let end = head ? c.y - half : c.y + half * 0.7
            var p = Path()
            p.move(to: CGPoint(x: c.x, y: end))
            p.addLine(to: CGPoint(x: c.x + width, y: c.y))
            p.addLine(to: CGPoint(x: c.x - width, y: c.y))
            p.closeSubpath()
            return p
        }
    }
}
