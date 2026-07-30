import SwiftUI

struct ActionRow: View {
    let title: String
    let systemImage: String
    var role: ButtonRole?
    var prominent = false
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            HStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .medium))
                    .frame(width: 30)
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundStyle(role == .destructive ? CuePilotTheme.destructive : .white)
            .padding(.horizontal, 20)
            .frame(minHeight: prominent ? 72 : 58)
            .background {
                RoundedRectangle(cornerRadius: CuePilotTheme.controlRadius, style: .continuous)
                    .fill(
                        prominent
                            ? AnyShapeStyle(CuePilotTheme.teal)
                            : AnyShapeStyle(.thinMaterial)
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: CuePilotTheme.controlRadius, style: .continuous)
                    .strokeBorder(
                        role == .destructive
                            ? CuePilotTheme.destructive
                            : CuePilotTheme.separator.opacity(prominent ? 0 : 0.8),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
    }
}
