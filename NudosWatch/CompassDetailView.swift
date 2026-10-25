import SwiftUI

/// Brújula ampliada al tocar la de la primera pantalla: marcas cada 5°, grados exactos
/// y, en naranja, entre qué rumbos ha oscilado el viento en los últimos 15 minutos.
struct CompassDetailView: View {
    @Environment(StationService.self) private var service
    @Environment(\.dismiss) private var dismiss

    // a pantalla completa; se cierra tocando en cualquier sitio. watchOS no deja quitar la hora,
    // así que la esfera va pegada abajo y el texto arriba a la izquierda, junto a la hora.
    var body: some View {
        let r = service.reading
        let spread = service.history?.directionSpread()
        ZStack {
            Color.black
            PrecisionCompass(degrees: r?.grados, spread: spread) { _ in
                VStack(spacing: -2) {
                    Text("\(r?.grados.fmt(0) ?? "—")°")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text(r?.direccion ?? "")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("\(r?.actual.fmt() ?? "—") kn")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.viento(r?.actual))
                }
                .monospacedDigit()
            }
            .padding(2)
            .frame(maxHeight: .infinity, alignment: .bottom)

            if let spread {
                Text("15′ \(directionRangeText(spread))")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.naranja)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.leading, 10)
                    .padding(.top, 10)
            }
        }
        .ignoresSafeArea()
        .toolbar(.hidden, for: .navigationBar)
        .contentShape(Rectangle())
        .onTapGesture { dismiss() }
    }
}

#Preview {
    CompassDetailView().environment(StationService.preview)
}
