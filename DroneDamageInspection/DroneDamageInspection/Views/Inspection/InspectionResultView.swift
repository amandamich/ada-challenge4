import SwiftUI

struct InspectionResultView: View {
    let results: [String]

    var body: some View {
        List(results, id: \.self) { result in
            Text(result)
                .font(.headline)
        }
    }
}

#Preview {
    InspectionResultView(results: ["Crack detected"])
}
