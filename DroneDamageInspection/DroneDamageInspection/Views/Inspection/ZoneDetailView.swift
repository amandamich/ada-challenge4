import SwiftUI

struct ZoneDetailView: View {
    let zone: BuildingZone
    let damages: [Damage]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(zone.displayName)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Text("\(damages.count) damage(s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if damages.isEmpty {
                Text("No damage recorded in this zone.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(damages) { damage in
                    DamageDetailView(damage: damage)
                }
            }
        }
        .padding(10)
        .background(.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    ZoneDetailView(
        zone: .defaultZone,
        damages: [Damage(type: "Crack", confidence: 0.87)]
    )
}
