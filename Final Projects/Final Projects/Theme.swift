import SwiftUI

enum AppColors {
    static let background = Color(red: 11 / 255, green: 12 / 255, blue: 14 / 255)
    static let cardBackground = Color(red: 22 / 255, green: 23 / 255, blue: 26 / 255)
    static let cardBorder = Color(red: 48 / 255, green: 49 / 255, blue: 55 / 255)
    static let cardDeep = Color(red: 18 / 255, green: 19 / 255, blue: 22 / 255)

    static let orangePrimary = Color(red: 122 / 255, green: 167 / 255, blue: 255 / 255)    // #7AA7FF
    static let orangeSecondary = Color(red: 181 / 255, green: 204 / 255, blue: 255 / 255)  // #B5CCFF
    static let orangeGlow = Color(red: 122 / 255, green: 167 / 255, blue: 255 / 255)

    static let textPrimary = Color(red: 248 / 255, green: 248 / 255, blue: 250 / 255)
    static let textSecondary = Color(red: 248 / 255, green: 248 / 255, blue: 250 / 255).opacity(0.70)
    static let placeholder = Color(red: 248 / 255, green: 248 / 255, blue: 250 / 255).opacity(0.35)

    static let openGreen = Color(red: 0.35, green: 0.86, blue: 0.55)
    static let closedRed = Color(red: 0.95, green: 0.25, blue: 0.30)
}

struct CinematicBackdrop: View {
    var body: some View {
        AppColors.background
    }
}

struct CinematicCardModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(AppColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    .padding(1)
            )
            .shadow(color: Color.black.opacity(0.40), radius: 18, x: 0, y: 12)
    }
}

struct PrimaryCinematicButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.white)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.orangePrimary)
                    .shadow(color: AppColors.orangeGlow.opacity(configuration.isPressed ? 0.18 : 0.28), radius: 14, x: 0, y: 10)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.85), value: configuration.isPressed)
    }
}

struct GhostCinematicButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(AppColors.textPrimary)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.28))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppColors.cardBorder, lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.85), value: configuration.isPressed)
    }
}

enum AppLayout {
    static let contentMaxWidth: CGFloat = 560
    static let listCardHeight: CGFloat = 340
    static let cardThumbnailHeight: CGFloat = 140
    static let spotlightThumbnailHeight: CGFloat = 190
    static let swipePhotoHeight: CGFloat = 210
}

private struct ContainerWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct CenteredConstrainedModifier: ViewModifier {
    let maxWidth: CGFloat

    @State private var containerWidth: CGFloat = 0

    func body(content: Content) -> some View {
        let desiredWidth = (containerWidth > 0) ? min(containerWidth, maxWidth) : maxWidth

        return HStack(spacing: 0) {
            Spacer(minLength: 0)
            content
                .frame(width: desiredWidth)
            Spacer(minLength: 0)
        }
        .background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: ContainerWidthKey.self, value: proxy.size.width)
            }
        )
        .onPreferenceChange(ContainerWidthKey.self) { newValue in
            containerWidth = newValue
        }
    }
}

extension View {
    func cinematicCard(cornerRadius: CGFloat = 18) -> some View {
        modifier(CinematicCardModifier(cornerRadius: cornerRadius))
    }

    func centeredConstrained(maxWidth: CGFloat = AppLayout.contentMaxWidth) -> some View {
        modifier(CenteredConstrainedModifier(maxWidth: maxWidth))
    }
}
