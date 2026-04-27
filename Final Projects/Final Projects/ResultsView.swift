import SwiftUI

struct ResultsView: View {
    @EnvironmentObject private var favorites: FavoritesManager

    let restaurants: [Restaurant]
    @Binding var sortOption: RestaurantSearchViewModel.SortOption

    var body: some View {
        ZStack {
            CinematicBackdrop().ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    sortBar
                        .padding(.horizontal, 20)
                        .padding(.top, 14)

                    LazyVStack(spacing: 20) {
                        ForEach(restaurants) { restaurant in
                            NavigationLink(value: restaurant) {
                                card(for: restaurant)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var sortBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("THE LIST")
                    .font(AppFonts.display(12, weight: .heavy))
                    .tracking(2)
                    .foregroundStyle(AppColors.orangeSecondary)

                Text("Tonight’s picks")
                    .font(AppFonts.display(22, weight: .heavy))
                    .foregroundStyle(AppColors.textPrimary)
                Text("\(restaurants.count) places")
                    .font(AppFonts.display(12, weight: .heavy))
                    .foregroundStyle(AppColors.textSecondary)
            }
            Spacer()
            Menu {
                Picker("Sort by", selection: $sortOption) {
                    ForEach(RestaurantSearchViewModel.SortOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(sortOption.rawValue)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                }
                .font(AppFonts.body(13, weight: .semibold))
                .foregroundStyle(AppColors.orangeSecondary)
            }
        }
        .padding(14)
        .cinematicCard(cornerRadius: 18)
        .centeredConstrained()
    }

    private func card(for restaurant: Restaurant) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topTrailing) {
                RestaurantImage(
                    photoReference: restaurant.photoReference,
                    height: AppLayout.cardThumbnailHeight,
                    cornerRadius: 14,
                    overlayStyle: .bottomFade(opacity: 0.55)
                )

                Button {
                    favorites.toggleFavorite(restaurant)
                } label: {
                    Image(systemName: favorites.isFavorited(restaurant) ? "heart.fill" : "heart")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(favorites.isFavorited(restaurant) ? AppColors.orangePrimary : Color.white)
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .padding(10)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(restaurant.name)
                    .font(AppFonts.display(20, weight: .heavy))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(2)
                    .frame(minHeight: 48, alignment: .topLeading)

                Text("\(restaurant.cuisine) • \(restaurant.priceSymbols)")
                    .font(AppFonts.body(14, weight: .semibold))
                    .foregroundStyle(AppColors.orangeSecondary)

                HStack(spacing: 10) {
                    Label(String(format: "%.1f", restaurant.rating), systemImage: "star.fill")
                        .foregroundStyle(AppColors.orangeSecondary)

                    Text(restaurant.isOpenNow ? "Open" : "Closed")
                        .foregroundStyle(restaurant.isOpenNow ? AppColors.openGreen : AppColors.closedRed)
                        .font(AppFonts.body(14, weight: .bold))
                }
                .font(AppFonts.body(14, weight: .semibold))

                HStack(alignment: .top, spacing: 10) {
                    if let distance = restaurant.distanceLabel {
                        Text(distance)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    Text(restaurant.address)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(2)
                        .frame(minHeight: 34, alignment: .topLeading)
                }
                .font(AppFonts.body(13, weight: .regular))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(height: AppLayout.listCardHeight, alignment: .top)
        .cinematicCard(cornerRadius: 18)
        .centeredConstrained()
    }
}

#Preview {
    NavigationStack {
        ResultsView(restaurants: [], sortOption: .constant(.rating))
            .environmentObject(FavoritesManager())
    }
}
