import SwiftUI

struct InspectionZoneSelectorView: View {
    @Bindable var inspectionViewModel: InspectionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Current Inspection Area")
                .font(.headline)

            Picker("Area", selection: zoneSelection) {
                ForEach(BuildingZone.zoneIdentifiers, id: \.self) { zone in
                    Text(zone).tag(zone)
                }
            }
            .pickerStyle(.menu)

            Text(inspectionViewModel.currentInspectionZone.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
    }

    private var zoneSelection: Binding<String> {
        Binding {
            inspectionViewModel.currentInspectionZone.zoneIdentifier
        } set: { zoneIdentifier in
            updateZone(zoneIdentifier: zoneIdentifier)
        }
    }

    private func updateZone(zoneIdentifier: String) {
        let currentZone = inspectionViewModel.currentInspectionZone
        inspectionViewModel.currentInspectionZone = BuildingZone(
            buildingName: currentZone.buildingName,
            floor: currentZone.floor,
            zoneIdentifier: zoneIdentifier
        )
    }
}

#Preview {
    InspectionZoneSelectorView(inspectionViewModel: InspectionViewModel())
}
