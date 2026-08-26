#if os(macOS)
import AppKit
#endif
import SwiftUI

struct InspectionResultView: View {
    let records: [InspectionRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if records.isEmpty {
                Text("No captured inspection frames")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(records) { record in
                    HStack(spacing: 12) {
                        if let image = record.capturedImage {
                            Image(decorative: image, scale: 1)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 96, height: 54)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        } else {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.secondary.opacity(0.18))
                                .frame(width: 96, height: 54)
                                .overlay {
                                    Image(systemName: "photo")
                                        .foregroundStyle(.secondary)
                                }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.createdAt.formatted(date: .abbreviated, time: .standard))
                                .font(.headline)

                            if let fileName = record.imageFileURL?.lastPathComponent {
                                Text(fileName)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Text(record.damageTypes.isEmpty ? "Ready for inspection" : record.damageTypes.joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if let imageFileURL = record.imageFileURL {
                            Button {
                                revealCapture(imageFileURL)
                            } label: {
                                Image(systemName: "folder")
                            }
                            .buttonStyle(.borderless)
                            .help("Reveal captured image in Finder")
                        }
                    }
                    .padding(8)
                    .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(.horizontal)
    }

    private func revealCapture(_ url: URL) {
        #if os(macOS)
        NSWorkspace.shared.activateFileViewerSelecting([url])
        #endif
    }
}

#Preview {
    InspectionResultView(records: [InspectionRecord(damageTypes: ["Crack"])])
}
