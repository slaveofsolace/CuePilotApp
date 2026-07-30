import ReplayKit
import SwiftUI
import UIKit

struct BroadcastPickerButton: View {
    var body: some View {
        HStack(spacing: 16) {
            SystemBroadcastPicker()
                .frame(width: 46, height: 46)
            Text("Start Broadcast")
                .font(.system(size: 18, weight: .semibold))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 15, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .accessibilityElement(children: .contain)
    }
}

private struct SystemBroadcastPicker: UIViewRepresentable {
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView(frame: .zero)
        picker.preferredExtension =
            "com.slaveofsolace.cuepilot.broadcast"
        picker.showsMicrophoneButton = false
        picker.tintColor = .white
        return picker
    }

    func updateUIView(
        _ uiView: RPSystemBroadcastPickerView,
        context: Context
    ) {}
}
