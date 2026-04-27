import SwiftUI

enum AppFonts {
    static func display(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        Font.custom("CalSans-Regular", size: size)
            .weight(weight)
    }

    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom("Alata-Regular", size: size)
            .weight(weight)
    }
}

