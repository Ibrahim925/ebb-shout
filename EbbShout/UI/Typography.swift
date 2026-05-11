import SwiftUI

extension Font {
    // Headlines and hero numbers use New York (Apple's built-in serif)
    static func ebDisplay(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    // Body and labels use SF Pro (default)
    static func ebBody(_ size: CGFloat = 14, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
    static func ebCaption(_ size: CGFloat = 11) -> Font {
        .system(size: size, weight: .regular)
    }
}

extension Color {
    static let ebAccent = Color(red: 0.48, green: 0.38, blue: 1.0)  // muted purple #7B61FF
}
