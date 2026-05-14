import SwiftUI
import TermCCore

struct SFTPDrawerView: View {
    @Bindable var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("SFTP")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                Button {
                    state.refreshRemoteFiles()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh")
            }

            Text(state.remotePath)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 8))

            VStack(spacing: 6) {
                ForEach(state.remoteFiles) { file in
                    HStack(spacing: 10) {
                        Image(systemName: file.kind == .file ? "doc" : "folder")
                            .foregroundStyle(.secondary)
                            .frame(width: 18)

                        Text(file.name)
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Spacer()

                        if file.kind == .file {
                            Text(ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file))
                                .foregroundStyle(.secondary)
                                .font(.caption2)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                }
            }

            Spacer(minLength: 0)

            if !state.transfers.isEmpty {
                Text("\(state.transfers.count) transfer\(state.transfers.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Button("Upload") {}
                    .frame(maxWidth: .infinity)

                Button("Download") {}
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(red: 0.12, green: 0.13, blue: 0.15))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1)
        }
    }
}

#Preview {
    SFTPDrawerView(state: AppState())
        .frame(width: 300, height: 640)
}
