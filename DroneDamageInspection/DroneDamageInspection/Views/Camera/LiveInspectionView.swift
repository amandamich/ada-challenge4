import SwiftUI

struct LiveInspectionView: View {
    @State private var isConnected = false
    @State private var inspectionResults: [String] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                DroneStatusView(isConnected: isConnected, batteryLevel: 0, altitude: 0)
                CameraView()

                DroneControlView(isConnected: isConnected) {
                    isConnected = true
                }

                Button("Inspect Frame") {
                    inspectionResults = ["No damage detected"]
                }
                .buttonStyle(.bordered)

                InspectionResultView(results: inspectionResults)
            }
            .navigationTitle("Drone Inspection")
        }
    }
}

#Preview {
    LiveInspectionView()
}
