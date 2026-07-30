#if os(iOS)
import SwiftUI

enum CuePilotTheme {
    static let canvas = Color(red: 13 / 255, green: 16 / 255, blue: 18 / 255)
    static let elevated = Color(red: 26 / 255, green: 30 / 255, blue: 32 / 255)
    static let table = Color(red: 13 / 255, green: 79 / 255, blue: 81 / 255)
    static let separator = Color(red: 52 / 255, green: 58 / 255, blue: 61 / 255)
    static let teal = Color(red: 22 / 255, green: 184 / 255, blue: 174 / 255)
    static let locked = Color(red: 120 / 255, green: 214 / 255, blue: 91 / 255)
    static let caution = Color(red: 240 / 255, green: 182 / 255, blue: 64 / 255)
    static let destructive = Color(red: 243 / 255, green: 77 / 255, blue: 77 / 255)

    static let contentPadding: CGFloat = 20
    static let controlRadius: CGFloat = 18
}

extension View {
    func cuePilotCanvas() -> some View {
        scrollContentBackground(.hidden)
            .background(CuePilotTheme.canvas.ignoresSafeArea())
            .tint(CuePilotTheme.teal)
            .preferredColorScheme(.dark)
    }
}
#endif
