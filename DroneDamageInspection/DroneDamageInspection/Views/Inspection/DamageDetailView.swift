#if os(macOS)
import AppKit
#endif
import SwiftUI

struct DamageDetailView: View {
    let damage: Damage

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(damage.type)
                        .font(.subheadline.weight(.semibold))

                    Text("ID: \(damage.id.uuidString)")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(damage.confidence.formatted(.percent.precision(.fractionLength(1))))
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.red.opacity(0.15), in: Capsule())
            }

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                GridRow {
                    Text("Location")
                        .foregroundStyle(.secondary)
                    Text(damage.inspectionZone.displayName)
                }

                GridRow {
                    Text("Timestamp")
                        .foregroundStyle(.secondary)
                    Text(damage.timestamp.formatted(date: .abbreviated, time: .standard))
                }
            }
            .font(.caption)

            if let evidenceImage = damage.evidenceImage {
                Image(decorative: evidenceImage, scale: 1)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            if let evidenceImageFileURL = damage.evidenceImageFileURL {
                Button {
                    revealEvidence(evidenceImageFileURL)
                } label: {
                    Label("Reveal Evidence", systemImage: "folder")
                }
                .font(.caption)
                .buttonStyle(.borderless)
            }
        }
        .padding(10)
        .background(.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
    }

    private func revealEvidence(_ url: URL) {
        #if os(macOS)
        NSWorkspace.shared.activateFileViewerSelecting([url])
        #endif
    }
}

#Preview {
    DamageDetailView(damage: Damage(type: "Crack", confidence: 0.91))
}
