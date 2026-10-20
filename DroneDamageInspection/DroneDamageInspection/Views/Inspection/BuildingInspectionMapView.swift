import SwiftUI

struct BuildingInspectionMapView: View {
    let damages: [Damage]
    @State private var selectedZone = BuildingZone.defaultZone

    private let columns = [
        GridItem(.adaptive(minimum: 130), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Inspection Map")
                .font(.headline)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(displayZones) { zone in
                    let count = damages(in: zone).count

                    Button {
                        selectedZone = zone
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(zone.zoneIdentifier)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if count > 0 {
                                Label("\(count) damage(s)", systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption.weight(.semibold))
                                    .labelStyle(.titleAndIcon)
                            } else {
                                Label("Clear", systemImage: "checkmark.circle")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
                        .padding(10)
                        .background(tileColor(hasDamage: count > 0), in: RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(selectedZone == zone ? .blue : .secondary.opacity(0.25), lineWidth: selectedZone == zone ? 2 : 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            ZoneDetailView(zone: selectedZone, damages: damages(in: selectedZone))
        }
        .padding()
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
    }

    private var displayZones: [BuildingZone] {
        BuildingZone.zoneIdentifiers.map { zone in
            BuildingZone(
                buildingName: BuildingZone.defaultZone.buildingName,
                floor: BuildingZone.defaultZone.floor,
                zoneIdentifier: zone
            )
        }
    }

    private func damages(in zone: BuildingZone) -> [Damage] {
        damages.filter { $0.inspectionZone == zone }
    }

    private func tileColor(hasDamage: Bool) -> Color {
        hasDamage ? .red.opacity(0.18) : .green.opacity(0.10)
    }
}

#Preview {
    BuildingInspectionMapView(damages: [
        Damage(type: "Crack", confidence: 0.87, inspectionZone: BuildingZone(buildingName: "Office", floor: 1, zoneIdentifier: "Main Lab"))
    ])
}
