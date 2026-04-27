import SwiftUI

struct SwipeView: View {
    @EnvironmentObject private var favorites: FavoritesManager

    let restaurants: [Restaurant]
    let onShowFavorites: () -> Void
    var isControlsExpanded: Bool = false

    @State private var index: Int = 0
    @State private var dragOffset: CGSize = .zero
    @State private var likedIDs: Set<String> = []
    @State private var savedRestaurant: Restaurant?

    private let swipeThreshold: CGFloat = 120

    var body: some View {
        ZStack {
            CinematicBackdrop().ignoresSafeArea()

            if restaurants.isEmpty {
                emptyState
            } else if index >= restaurants.count {
                summaryState
            } else {
                GeometryReader { proxy in
                    let maxCardWidth = min(proxy.size.width - 36, AppLayout.contentMaxWidth)
                    let chromeHeight: CGFloat = 170
                    let availableHeight = max(0, proxy.size.height - chromeHeight)
                    let cardHeight = min(440, availableHeight)
                    let restaurant = restaurants[index]
                    let nextRestaurant = (index + 1 < restaurants.count) ? restaurants[index + 1] : nil
                    let overlayTopPadding: CGFloat = isControlsExpanded ? 24 : 14

                    VStack(spacing: 10) {
                        topBar(current: index + 1, total: restaurants.count, maxWidth: maxCardWidth)
                            .padding(.top, 8)

                        HStack(spacing: 0) {
                            Spacer(minLength: 0)

                            ZStack {
                                if let nextRestaurant {
                                    SwipeDeckCard(
                                        restaurant: nextRestaurant,
                                        dragOffset: .zero,
                                        height: cardHeight,
                                        overlayTopPadding: overlayTopPadding,
                                        isInteractive: false
                                    )
                                    .scaleEffect(0.96)
                                    .opacity(0.55)
                                    .offset(y: 10)
                                }

                                NavigationLink(value: restaurant) {
                                    SwipeDeckCard(
                                        restaurant: restaurant,
                                        dragOffset: dragOffset,
                                        height: cardHeight,
                                        overlayTopPadding: overlayTopPadding,
                                        isInteractive: true
                                    )
                                }
                                .buttonStyle(.plain)
                                .contentShape(Rectangle())
                                .highPriorityGesture(
                                    DragGesture()
                                        .onChanged { value in
                                            dragOffset = value.translation
                                        }
                                        .onEnded { _ in
                                            handleDragEnd()
                                        }
                                )
                                .animation(.spring(response: 0.35, dampingFraction: 0.86), value: dragOffset)
                            }
                            .frame(width: maxCardWidth, height: cardHeight)

                            Spacer(minLength: 0)
                        }
                        .animation(.spring(response: 0.32, dampingFraction: 0.88), value: isControlsExpanded)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
        }
        .overlay {
            if let savedRestaurant {
                SaveSplash(
                    restaurant: savedRestaurant,
                    onClose: { self.savedRestaurant = nil },
                    onShowFavorites: onShowFavorites
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                .zIndex(10)
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.88), value: savedRestaurant?.id)
        .onChange(of: restaurants.count) { _, _ in
            if index >= restaurants.count {
                index = 0
            }
        }
    }

    private func topBar(current: Int, total: Int, maxWidth: CGFloat) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SWIPE")
                    .font(AppFonts.display(12, weight: .heavy))
                    .tracking(2)
                    .foregroundStyle(AppColors.orangeSecondary)

                Text("\(current) of \(total)")
                    .font(AppFonts.display(15, weight: .heavy))
                    .foregroundStyle(AppColors.textPrimary)
            }

            Spacer()

            Button("Favorites") {
                onShowFavorites()
            }
            .font(AppFonts.display(13, weight: .heavy))
            .buttonStyle(GhostCinematicButtonStyle())
        }
        .padding(14)
        .cinematicCard(cornerRadius: 20)
        .centeredConstrained(maxWidth: maxWidth)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "fork.knife")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(AppColors.orangePrimary)
            Text("No restaurants found — try adjusting your filters")
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
    }

    private var summaryState: some View {
        VStack(spacing: 14) {
            Text("You liked \(likedIDs.count) places!")
                .font(AppFonts.display(28, weight: .heavy))
                .foregroundStyle(AppColors.textPrimary)

            Button {
                onShowFavorites()
            } label: {
                Text("View Favorites")
                    .font(AppFonts.display(16, weight: .bold))
                    .frame(maxWidth: 260)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.orangePrimary)

            Button {
                reset()
            } label: {
                Text("Swipe Again")
                    .font(AppFonts.body(15, weight: .semibold))
                    .foregroundStyle(AppColors.orangeSecondary)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private func handleDragEnd() {
        if dragOffset.width > swipeThreshold {
            swipeRight()
        } else if dragOffset.width < -swipeThreshold {
            swipeLeft()
        } else {
            dragOffset = .zero
        }
    }

    private func swipeRight() {
        let restaurant = restaurants[index]
        if !favorites.isFavorited(restaurant) {
            favorites.toggleFavorite(restaurant)
        }
        likedIDs.insert(restaurant.id)
        savedRestaurant = restaurant

        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            dragOffset = CGSize(width: 900, height: 0)
        }

        advanceAfterDelay()
    }

    private func swipeLeft() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            dragOffset = CGSize(width: -900, height: 0)
        }

        advanceAfterDelay()
    }

    private func advanceAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            dragOffset = .zero
            index += 1
        }
    }

    private func reset() {
        index = 0
        dragOffset = .zero
        likedIDs = []
    }
}

private struct SwipeDeckCard: View {
    let restaurant: Restaurant
    let dragOffset: CGSize
    let height: CGFloat
    let overlayTopPadding: CGFloat
    let isInteractive: Bool

    var body: some View {
        ZStack {
            RestaurantImage(
                photoReference: restaurant.photoReference,
                height: height,
                cornerRadius: 28,
                overlayStyle: .bottomFade(opacity: 0.70)
            )

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    pill(text: restaurant.isOpenNow ? "Open" : "Closed", tint: restaurant.isOpenNow ? AppColors.openGreen : AppColors.closedRed)

                    if let distance = restaurant.distanceLabel {
                        pill(text: distance, tint: AppColors.textPrimary)
                    }

                    Spacer()

                    pill(text: restaurant.priceSymbols, tint: AppColors.orangeSecondary)
                }
                .padding(.top, overlayTopPadding)
                .padding(.horizontal, 14)

                Spacer()

                VStack(alignment: .leading, spacing: 8) {
                    Text(restaurant.name)
                        .font(AppFonts.display(26, weight: .heavy))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.86)

                    HStack(spacing: 10) {
                        Text(restaurant.cuisine)
                            .foregroundStyle(AppColors.orangeSecondary)

                        Text("•")
                            .foregroundStyle(AppColors.textSecondary)

                        Label(String(format: "%.1f", restaurant.rating), systemImage: "star.fill")
                            .labelStyle(.titleAndIcon)
                            .foregroundStyle(AppColors.orangeSecondary)
                    }
                    .font(AppFonts.body(14, weight: .semibold))

                    Text(restaurant.address)
                        .font(AppFonts.body(13, weight: .semibold))
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(2)
                }
                .padding(14)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
                .padding(14)
            }

            if isInteractive {
                dragOverlay
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .offset(dragOffset)
        .rotationEffect(.degrees(Double(dragOffset.width / 18)))
    }

    private var dragOverlay: some View {
        Group {
            if dragOffset.width > 46 {
                stamp(text: "SAVE", tint: AppColors.openGreen)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(18)
            } else if dragOffset.width < -46 {
                stamp(text: "SKIP", tint: AppColors.closedRed)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(18)
            }
        }
        .allowsHitTesting(false)
    }

    private func pill(text: String, tint: Color) -> some View {
        Text(text)
            .font(AppFonts.display(12, weight: .heavy))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.black.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 999))
            .overlay(
                RoundedRectangle(cornerRadius: 999)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
    }

    private func stamp(text: String, tint: Color) -> some View {
        Text(text)
            .font(AppFonts.display(34, weight: .heavy))
            .tracking(2)
            .foregroundStyle(tint)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.40))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(tint.opacity(0.8), lineWidth: 2)
            )
            .rotationEffect(.degrees(text == "SAVE" ? -12 : 12))
            .shadow(color: Color.black.opacity(0.45), radius: 10, x: 0, y: 8)
    }
}

private struct SaveSplash: View {
    let restaurant: Restaurant
    let onClose: () -> Void
    let onShowFavorites: () -> Void

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.60))
                .ignoresSafeArea()
                .onTapGesture {
                    onClose()
                }

            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("SAVED")
                        .font(AppFonts.display(12, weight: .heavy))
                        .tracking(2)
                        .foregroundStyle(AppColors.orangeSecondary)

                    Text(restaurant.name)
                        .font(AppFonts.display(28, weight: .heavy))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(2)

                    Text("\(restaurant.cuisine) • \(restaurant.priceSymbols)")
                        .font(AppFonts.body(14, weight: .semibold))
                        .foregroundStyle(AppColors.orangeSecondary)

                    HStack(spacing: 10) {
                        Label(String(format: "%.1f", restaurant.rating), systemImage: "star.fill")
                            .foregroundStyle(AppColors.orangeSecondary)
                        Text(restaurant.isOpenNow ? "Open" : "Closed")
                            .foregroundStyle(restaurant.isOpenNow ? AppColors.openGreen : AppColors.closedRed)
                            .font(AppFonts.body(14, weight: .bold))
                        if let distance = restaurant.distanceLabel {
                            Text("• \(distance)")
                                .foregroundStyle(AppColors.textSecondary)
                                .font(AppFonts.body(14, weight: .semibold))
                        }
                    }
                    .font(AppFonts.body(14, weight: .semibold))

                    Text(restaurant.address)
                        .font(AppFonts.body(13, weight: .semibold))
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(3)
                        .padding(.top, 2)
                }

                HStack(spacing: 12) {
                    NavigationLink(value: restaurant) {
                        Text("View Details")
                            .font(AppFonts.display(15, weight: .heavy))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(PrimaryCinematicButtonStyle())
                    .simultaneousGesture(TapGesture().onEnded { onClose() })

                    Button("Favorites") {
                        onClose()
                        onShowFavorites()
                    }
                    .font(AppFonts.display(15, weight: .heavy))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .buttonStyle(GhostCinematicButtonStyle())
                }

                Button("Continue Swiping") {
                    onClose()
                }
                .font(AppFonts.display(14, weight: .heavy))
                .foregroundStyle(AppColors.orangeSecondary)
                .padding(.top, 2)
            }
            .padding(18)
            .cinematicCard(cornerRadius: 22)
            .frame(maxWidth: 520)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .accessibilityAddTraits(.isModal)
    }
}

#Preview {
    SwipeView(
        restaurants: [
            Restaurant(
                id: "1",
                name: "Midnight Ramen",
                address: "123 Noir Street",
                rating: 4.6,
                priceLevel: 2,
                isOpenNow: true,
                cuisine: "Japanese",
                photoReference: nil,
                phoneNumber: nil,
                website: nil,
                weekdayHours: [],
                latitude: 0,
                longitude: 0,
                distanceMiles: 1.2,
                isFavorited: false
            ),
            Restaurant(
                id: "2",
                name: "Neon Tacos",
                address: "456 Sunset Blvd",
                rating: 4.2,
                priceLevel: 1,
                isOpenNow: false,
                cuisine: "Mexican",
                photoReference: nil,
                phoneNumber: nil,
                website: nil,
                weekdayHours: [],
                latitude: 0,
                longitude: 0,
                distanceMiles: 2.8,
                isFavorited: false
            )
        ],
        onShowFavorites: {}
    )
    .environmentObject(FavoritesManager())
}
