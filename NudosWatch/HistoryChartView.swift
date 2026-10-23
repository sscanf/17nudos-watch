import SwiftUI
import Charts

struct HistoryChartView: View {
    @Environment(StationService.self) private var service

    var body: some View {
        if let h = service.history {
            let samples = Self.downsample(h.samples, every: 5)
            VStack(alignment: .leading, spacing: 2) {
                Chart {
                    ForEach(samples) { s in
                        if let g = s.racha {
                            AreaMark(x: .value("Hora", s.date), y: .value("Racha", g),
                                     series: .value("Serie", "Racha"))
                                .foregroundStyle(Theme.naranja.opacity(0.25))
                                .interpolationMethod(.monotone)
                        }
                    }
                    ForEach(samples) { s in
                        if let n = s.nominal {
                            LineMark(x: .value("Hora", s.date), y: .value("Nudos", n),
                                     series: .value("Serie", "Nominal"))
                                .foregroundStyle(Theme.azul)
                                .lineStyle(StrokeStyle(lineWidth: 2))
                                .interpolationMethod(.monotone)
                        }
                    }
                    RuleMark(y: .value("Umbral", Theme.umbralNudos))
                        .foregroundStyle(Theme.verde.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.hour())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 3))
                }
                HStack(spacing: 8) {
                    Legend(color: Theme.azul, text: "Nominal")
                    Legend(color: Theme.naranja, text: "Racha")
                    Legend(color: Theme.verde, text: ">8 kn")
                }
            }
        } else {
            ProgressView()
        }
    }

    /// Agrupa muestras de 1 min en bloques: media del nominal y máxima de la racha,
    /// como hace la gráfica de la web para que no salga en dientes de sierra.
    static func downsample(_ s: [WindHistory.Sample], every n: Int) -> [WindHistory.Sample] {
        stride(from: 0, to: s.count, by: n).map { i in
            let chunk = s[i..<min(i + n, s.count)]
            let noms = chunk.compactMap(\.nominal)
            let gusts = chunk.compactMap(\.racha)
            return WindHistory.Sample(
                date: chunk[chunk.startIndex + chunk.count / 2].date,
                nominal: noms.isEmpty ? nil : noms.reduce(0, +) / Double(noms.count),
                racha: gusts.max().map { max($0, noms.max() ?? $0) }
            )
        }
    }

    private struct Legend: View {
        var color: Color
        var text: String
        var body: some View {
            HStack(spacing: 2) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(text).font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
    }
}
