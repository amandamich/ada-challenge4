#if os(macOS)
import AppKit
#endif
import SwiftUI

struct InspectionResultView: View {
    let records: [InspectionRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !records.isEmpty {
                Text("Inspection Records")
                    .font(.headline)
                    .padding(.horizontal)
            }

            if records.isEmpty {
                Text("No captured inspection frames")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                ForEach(records) { record in
                    VStack(alignment: .leading, spacing: 8) {
                        if let image = record.capturedImage {
                            Image(decorative: image, scale: 1)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 200)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.secondary.opacity(0.18))
                                .frame(maxWidth: .infinity)
                                .frame(height: 200)
                                .overlay {
                                    Image(systemName: "photo")
                                        .font(.largeTitle)
                                        .foregroundStyle(.secondary)
                                }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(record.createdAt.formatted(date: .abbreviated, time: .standard))
                                    .font(.subheadline.weight(.semibold))

                                Spacer()

                                if let fileName = record.imageFileURL?.lastPathComponent {
                                    Text(fileName)
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }

                            if record.detections.isEmpty {
                                Text("No damage detected")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("\(record.detections.count) detection(s)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if !record.detections.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(record.detections) { detection in
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(.red)
                                            .frame(width: 6, height: 6)

                                        Text(detection.damageType)
                                            .font(.caption.weight(.semibold))

                                        Text("\(Int(detection.confidence * 100))%")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        Spacer()

                                        if let imageFileURL = record.imageFileURL {
                                            Button {
                                                revealCapture(imageFileURL)
                                            } label: {
                                                Image(systemName: "folder")
                                            }
                                            .buttonStyle(.borderless)
                                            .help("Reveal in Finder")
                                        }
                                    }
                                }
                            }
                            .padding(8)
                            .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                        } else if let imageFileURL = record.imageFileURL {
                            HStack {
                                Spacer()
                                Button {
                                    revealCapture(imageFileURL)
                                } label: {
                                    Image(systemName: "folder")
                                }
                                .buttonStyle(.borderless)
                                .help("Reveal in Finder")
                            }
                        }
                    }
                    .padding(8)
                    .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
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
