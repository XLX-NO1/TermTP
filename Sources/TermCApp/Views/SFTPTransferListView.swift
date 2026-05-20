import SwiftUI
import TermCCore

struct SFTPTransferListView: View {
    @Bindable var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(state.t.transfers)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.78))

                Spacer()

                Button {
                    state.clearFinishedTransfersForSelectedTab()
                } label: {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.68))
                .help(state.t.clearFinishedTransfers)
            }

            ForEach(state.visibleTransfers.suffix(3)) { transfer in
                transferRow(transfer)
            }
        }
    }

    private func transferRow(_ transfer: TransferRecord) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: transfer.direction == .download ? "arrow.down.circle" : "arrow.up.circle")
                    .foregroundStyle(.white.opacity(0.72))

                Text(URL(fileURLWithPath: transfer.direction == .download ? transfer.remotePath : transfer.localPath).lastPathComponent)
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer()

                Text(transferLabel(for: transfer))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.68))

                transferActions(for: transfer)
            }

            ProgressView(value: transferProgress(for: transfer))
                .progressViewStyle(.linear)
                .controlSize(.small)

            if transfer.state == .failed, let errorMessage = transfer.errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(.red.opacity(0.82))
                    .lineLimit(2)
            }
        }
    }

    @ViewBuilder
    private func transferActions(for transfer: TransferRecord) -> some View {
        switch transfer.state {
        case .running, .queued:
            Button {
                state.cancelTransfer(transfer.id)
            } label: {
                Image(systemName: "xmark.circle")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.74))
            .help(state.t.cancel)
        case .failed, .cancelled:
            Button {
                Task {
                    await state.retryTransfer(transfer.id)
                }
            } label: {
                Image(systemName: "arrow.clockwise.circle")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.74))
            .help(state.t.retry)
        case .completed:
            EmptyView()
        }
    }

    private func transferProgress(for transfer: TransferRecord) -> Double {
        guard transfer.totalBytes > 0 else {
            return transfer.state == .completed ? 1 : 0
        }

        return min(1, max(0, Double(transfer.bytesCompleted) / Double(transfer.totalBytes)))
    }

    private func transferLabel(for transfer: TransferRecord) -> String {
        switch transfer.state {
        case .completed:
            return state.t.done
        case .failed:
            return state.t.failed
        case .cancelled:
            return state.t.cancelled
        case .queued:
            return state.t.queued
        case .running:
            if transfer.totalBytes > 0 {
                let completed = ByteCountFormatter.string(fromByteCount: transfer.bytesCompleted, countStyle: .file)
                let total = ByteCountFormatter.string(fromByteCount: transfer.totalBytes, countStyle: .file)
                var parts = ["\(completed) / \(total)"]
                if transfer.bytesPerSecond > 0 {
                    parts.append(ByteCountFormatter.string(fromByteCount: Int64(transfer.bytesPerSecond), countStyle: .file) + "/s")
                }
                if let remaining = transfer.estimatedSecondsRemaining {
                    parts.append(formatRemainingTime(remaining))
                }
                return parts.joined(separator: "  ")
            }
            return state.t.running
        }
    }

    private func formatRemainingTime(_ seconds: TimeInterval) -> String {
        let totalSeconds = max(0, Int(seconds.rounded(.up)))
        if totalSeconds < 60 {
            return state.t.secondsRemaining(totalSeconds)
        }

        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return state.t.minutesSecondsRemaining(minutes, seconds)
    }
}
