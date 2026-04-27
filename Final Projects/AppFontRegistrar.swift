import Foundation
import CoreText

enum AppFontRegistrar {
    static func registerFonts() {
        registerFont(resourceName: "Alata-Regular", fileExtension: "ttf")
        registerFont(resourceName: "CalSans-Regular", fileExtension: "ttf")
    }

    private static func registerFont(resourceName: String, fileExtension: String) {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: fileExtension) else {
            return
        }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
}

