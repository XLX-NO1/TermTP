import SwiftUI
import TermCCore

struct SFTPDrawerView: View {
    let transfers: [TransferRecord]

    private let files = [
        ("index.html", "12 KB"),
        ("release.tar.gz", "84 MB"),
        ("assets", "Folder"),
        ("logs", "Folder")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("SFTP")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                Button {
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh")
            }

            Text("/var/www")
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 8))

            VStack(spacing: 6) {
                ForEach(files, id: \.0) { file in
                    HStack(spacing: 10) {
                        Image(systemName: file.1 == "Folder" ? "folder" : "doc")
                            .foregroundStyle(.secondary)
                            .frame(width: 18)

                        Text(file.0)
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Spacer()

                        Text(file.1)
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                }
            }

            Spacer(minLength: 0)

            if !transfers.isEmpty {
                Text("\(transfers.count) transfer\(transfers.count == 1 ? "" : "s")")
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
    SFTPDrawerView(transfers: [])
        .frame(width: 300, height: 640)
}
