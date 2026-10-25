import SwiftUI

/// Brújula ampliada al tocar la de la primera pantalla: marcas cada 5°, grados exactos
/// y, en naranja, entre qué rumbos ha oscilado el viento en los últimos 15 minutos.
struct CompassDetailView: View {
    @Environment(StationService.self) private var service

    var body: some View {
        let r = service.reading
        let spread = service.history?.directionSpread()
        VStack(spacing: 2) {
            ZStack {
                Dial(spread: spread)
                if let deg = r?.grados {
                    ZStack {
                        Needle(head: false).fill(.white.opacity(0.5))
                        Needle(head: true).fill(Theme.naranja)
                    }
                        .padding(12)
                        .rotationEffect(.degrees(deg))  // hacia donde viene
                        .animation(.easeInOut, value: deg)
                }
                // centro: el número tapa el pie de la aguja
                VStack(spacing: -2) {
                    Text("\(r?.grados.fmt(0) ?? "—")°")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(r?.direccion ?? "")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 52, height: 52)
                .background(.black, in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))
            }
            .aspectRatio(1, contentMode: .fit)

            HStack(spacing: 6) {
                Text("\(r?.actual.fmt() ?? "—") kn")
                    .foregroundStyle(Theme.viento(r?.actual))
                if let spread {
                    Text("15′ \(Self.range(spread))")
                        .foregroundStyle(Theme.naranja)
                }
            }
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
    }

    /// "205°–240°": de dónde ha venido el viento en el último cuarto de hora.
    private static func range(_ s: (mean: Double, left: Double, right: Double)) -> String {
        func norm(_ d: Double) -> Int { Int((d + 360).truncatingRemainder(dividingBy: 360).rounded()) }
        return "\(norm(s.mean - s.left))°–\(norm(s.mean + s.right))°"
    }

    /// Esfera: marcas, números cada 30° (los cardinales con letra) y el arco de variación.
    private struct Dial: View {
        var spread: (mean: Double, left: Double, right: Double)?

        var body: some View {
            GeometryReader { geo in
                let d = min(geo.size.width, geo.size.height)
                let radius = d / 2
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                ZStack {
                    if let spread {
                        // al menos unos grados para que se vea aunque el viento esté muy estable
                        let left = max(spread.left, 3), right = max(spread.right, 3)
                        Path { p in
                            p.addArc(center: center, radius: radius - 6,
                                     startAngle: .degrees(spread.mean - left - 90),
                                     endAngle: .degrees(spread.mean + right - 90), clockwise: false)
                        }
                        .stroke(Theme.naranja.opacity(0.45), style: StrokeStyle(lineWidth: 12, lineCap: .butt))
                    }
                    Canvas { ctx, _ in
                        for deg in stride(from: 0, to: 360, by: 5) {
                            let len: CGFloat = deg % 30 == 0 ? 11 : deg % 10 == 0 ? 7 : 4
                            let a = Double(deg - 90) * .pi / 180
                            var tick = Path()
                            tick.move(to: CGPoint(x: center.x + cos(a) * radius, y: center.y + sin(a) * radius))
                            tick.addLine(to: CGPoint(x: center.x + cos(a) * (radius - len),
                                                     y: center.y + sin(a) * (radius - len)))
                            ctx.stroke(tick, with: .color(.white.opacity(deg % 10 == 0 ? 0.8 : 0.4)),
                                       lineWidth: deg % 30 == 0 ? 2 : 1)
                        }
                    }
                    ForEach(Array(stride(from: 0, to: 360, by: 30)), id: \.self) { deg in
                        Label(deg: deg)
                            .position(x: center.x + sin(Double(deg) * .pi / 180) * (radius - 22),
                                      y: center.y - cos(Double(deg) * .pi / 180) * (radius - 22))
                    }
                }
            }
        }

        private struct Label: View {
            var deg: Int
            private static let cardinals = [0: "N", 90: "E", 180: "S", 270: "W"]

            var body: some View {
                if let c = Self.cardinals[deg] {
                    Text(c)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(deg == 0 ? Theme.naranja : .white)
                } else {
                    Text("\(deg)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// Aguja fina: la punta (hacia arriba, luego se gira) o la cola, más corta.
    private struct Needle: Shape {
        var head: Bool

        func path(in rect: CGRect) -> Path {
            let c = CGPoint(x: rect.midX, y: rect.midY)
            let half = min(rect.width, rect.height) / 2
            let end = head ? c.y - half : c.y + half * 0.7
            var p = Path()
            p.move(to: CGPoint(x: c.x, y: end))
            p.addLine(to: CGPoint(x: c.x + 6, y: c.y))
            p.addLine(to: CGPoint(x: c.x - 6, y: c.y))
            p.closeSubpath()
            return p
        }
    }
}

#Preview {
    CompassDetailView().environment(StationService.preview)
}
