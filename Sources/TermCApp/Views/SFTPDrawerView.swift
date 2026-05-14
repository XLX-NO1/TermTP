import SwiftUI
import TermCCore

struct SFTPDrawerView: View {
    @Bindable var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("SFTP")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                Spacer()

                Button {
                    state.refreshRemoteFiles()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .help("Refresh")
            }

            Text(state.remotePath)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.white.opacity(0.70))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.26), in: RoundedRectangle(cornerRadius: 6))

            HStack(spacing: 6) {
                ForEach(state.remoteFiles) { file in
                    HStack(spacing: 10) {
                        Image(systemName: file.kind == .file ? "doc" : "folder")
                            .foregroundStyle(.white.opacity(0.70))
                            .frame(width: 14)

                        Text(file.name)
                            .font(.caption)
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Spacer()

                        if file.kind == .file {
                            Text(ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file))
                                .foregroundStyle(.white.opacity(0.62))
                                .font(.caption2)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
                }
            }

            Spacer(minLength: 0)

            if !state.transfers.isEmpty {
                Text("\(state.transfers.count) transfer\(state.transfers.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.70))
            }

            HStack(spacing: 8) {
                Spacer(minLength: 0)

                Button("Upload") {}
                    .frame(width: 92)

                Button("Download") {}
                    .frame(width: 92)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(red: 0.12, green: 0.13, blue: 0.15))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
    }
}

#Preview {
    SFTPDrawerView(state: AppState())
        .frame(width: 720, height: AppLayout.transferDrawerHeight)
}
