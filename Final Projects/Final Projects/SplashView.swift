import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            CinematicBackdrop()
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 64, weight: .heavy))
                    .foregroundStyle(AppColors.orangePrimary)

                Text(AppStrings.appTitle)
                    .font(AppFonts.display(26, weight: .heavy))
                    .foregroundStyle(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(24)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(AppStrings.appTitle) loading")
    }
}

#Preview {
    SplashView()
}
