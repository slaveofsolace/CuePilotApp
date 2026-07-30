import SwiftUI

struct SecondaryToolsView: View {
    var body: some View {
        List {
            Section {
                toolRow(
                    title: "Anagrams and Word Hunt",
                    detail: "OCR, grid review, and local word solving",
                    icon: "textformat.abc",
                    status: "Deferred"
                )
                toolRow(
                    title: "Darts",
                    detail: "Visible board and target analysis",
                    icon: "scope",
                    status: "Deferred"
                )
                toolRow(
                    title: "Archery and Tanks",
                    detail: "Visible wind and counter-aim analysis",
                    icon: "wind",
                    status: "Deferred"
                )
                toolRow(
                    title: "Cup Pong and Mini Golf",
                    detail: "Visible path and bank estimation",
                    icon: "point.forward.to.point.capsulepath",
                    status: "Deferred"
                )
                toolRow(
                    title: "Sea Battle",
                    detail: "Legal probability heatmap",
                    icon: "square.grid.3x3",
                    status: "Deferred"
                )
            } footer: {
                Text(
                    "These tools will use only visible information and will never "
                    + "inject input, alter physics, reveal hidden state, or spoof results."
                )
            }
        }
        .navigationTitle("Secondary Tools")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func toolRow(
        title: String,
        detail: String,
        icon: String,
        status: String
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 17, weight: .medium))
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(status)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}
