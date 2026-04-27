import SwiftUI

struct DetailView: View {
    @EnvironmentObject private var favorites: FavoritesManager
    @Environment(\.openURL) private var openURL

    let restaurant: Restaurant
    private let detailMaxWidth: CGFloat = 360

    var body: some View {
        ZStack {
            CinematicBackdrop().ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    hero

                    details
                        .padding(.bottom, 24)
                        .centeredConstrained(maxWidth: detailMaxWidth)
                }
                .padding(.horizontal, 18)
            }
        }
        .scrollIndicators(.hidden)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    favorites.toggleFavorite(restaurant)
                } label: {
                    Image(systemName: favorites.isFavorited(restaurant) ? "heart.fill" : "heart")
                        .foregroundStyle(favorites.isFavorited(restaurant) ? AppColors.orangePrimary : Color.white)
                }
            }
        }
        .toolbar(.visible, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            RestaurantImage(photoReference: restaurant.photoReference, height: 280, maxWidth: nil, cornerRadius: 0)
                .overlay(
                    LinearGradient(
                        colors: [Color.black.opacity(0.10), Color.black.opacity(0.75)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            VStack(alignment: .leading, spacing: 10) {
                Text("FEATURE")
                    .font(AppFonts.display(12, weight: .heavy))
                    .tracking(2)
                    .foregroundStyle(AppColors.orangeSecondary)

                Text(restaurant.name)
                    .font(AppFonts.display(26, weight: .heavy))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)

                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        chip("\(restaurant.cuisine)")
                        chip("\(restaurant.priceSymbols)")
                        if let distance = restaurant.distanceLabel {
                            chip(distance)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)

                HStack(spacing: 10) {
                    stars
                    Text(String(format: "%.1f", restaurant.rating))
                        .foregroundStyle(AppColors.orangeSecondary)
                        .font(AppFonts.display(13, weight: .heavy))
                    openStatus
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            .frame(maxWidth: detailMaxWidth, alignment: .leading)
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 14) {
            overviewCard
            actionCard

            if !restaurant.weekdayHours.isEmpty {
                hoursCard
            }

            if restaurant.phoneNumber != nil || restaurant.website != nil {
                contactCard
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Overview")
                        .font(AppFonts.display(12, weight: .heavy))
                        .tracking(2)
                        .foregroundStyle(AppColors.orangeSecondary)

                    Text(restaurant.address)
                        .foregroundStyle(AppColors.textSecondary)
                        .font(AppFonts.body(14, weight: .semibold))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Button {
                    favorites.toggleFavorite(restaurant)
                } label: {
                    Image(systemName: favorites.isFavorited(restaurant) ? "heart.fill" : "heart")
                        .font(AppFonts.display(15, weight: .heavy))
                        .foregroundStyle(favorites.isFavorited(restaurant) ? AppColors.orangePrimary : AppColors.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(AppColors.cardBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(favorites.isFavorited(restaurant) ? "Remove from favorites" : "Add to favorites")
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    stars
                    Text(String(format: "%.1f", restaurant.rating))
                        .foregroundStyle(AppColors.textSecondary)
                        .font(AppFonts.body(13, weight: .semibold))
                    openStatus
                    if let distance = restaurant.distanceLabel {
                        Text("• \(distance)")
                            .foregroundStyle(AppColors.textSecondary)
                            .font(AppFonts.body(13, weight: .semibold))
                    }
                }

                Text("\(restaurant.cuisine) • \(restaurant.priceSymbols)")
                    .font(AppFonts.display(13, weight: .heavy))
                    .foregroundStyle(AppColors.orangeSecondary)
                    .lineLimit(1)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cinematicCard(cornerRadius: 22)
    }

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Actions")
                .font(AppFonts.display(12, weight: .heavy))
                .tracking(2)
                .foregroundStyle(AppColors.orangeSecondary)

            HStack(spacing: 12) {
                Button {
                    openDirections()
                } label: {
                    Label("Directions", systemImage: "map")
                        .font(AppFonts.display(14, weight: .heavy))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(PrimaryCinematicButtonStyle())

                ShareLink(item: "\(restaurant.name) — \(restaurant.address)") {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(AppFonts.display(14, weight: .heavy))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(GhostCinematicButtonStyle())
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cinematicCard(cornerRadius: 22)
    }

    private var hoursCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hours")
                .font(AppFonts.display(12, weight: .heavy))
                .tracking(2)
                .foregroundStyle(AppColors.orangeSecondary)

            ForEach(restaurant.weekdayHours, id: \.self) { line in
                Text(line)
                    .foregroundStyle(AppColors.textSecondary)
                    .font(AppFonts.body(13, weight: .regular))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cinematicCard(cornerRadius: 22)
    }

    private var contactCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Contact")
                .font(AppFonts.display(12, weight: .heavy))
                .tracking(2)
                .foregroundStyle(AppColors.orangeSecondary)

            if let phone = restaurant.phoneNumber, let url = URL(string: "tel:\(digitsOnly(phone))") {
                Link(destination: url) {
                    detailRow(icon: "phone.fill", title: phone)
                }
                .tint(AppColors.orangeSecondary)
            }

            if let website = restaurant.website, let url = URL(string: website) {
                Link(destination: url) {
                    detailRow(icon: "globe", title: website)
                }
                .tint(AppColors.orangeSecondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cinematicCard(cornerRadius: 22)
    }

    private var stars: some View {
        let full = Int(restaurant.rating.rounded(.down))
        let hasHalf = restaurant.rating - Double(full) >= 0.5
        let empty = max(0, 5 - full - (hasHalf ? 1 : 0))

        return HStack(spacing: 2) {
            ForEach(0..<full, id: \.self) { _ in
                Image(systemName: "star.fill")
            }
            if hasHalf {
                Image(systemName: "star.leadinghalf.filled")
            }
            ForEach(0..<empty, id: \.self) { _ in
                Image(systemName: "star")
            }
        }
        .foregroundStyle(AppColors.orangeSecondary)
        .font(AppFonts.body(13, weight: .bold))
    }

    private var openStatus: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(restaurant.isOpenNow ? AppColors.openGreen : AppColors.closedRed)
                .frame(width: 8, height: 8)
            Text(restaurant.isOpenNow ? "Open" : "Closed")
                .foregroundStyle(restaurant.isOpenNow ? AppColors.openGreen : AppColors.closedRed)
                .font(AppFonts.body(14, weight: .bold))
        }
    }

    private func openDirections() {
        let url = URL(string: "maps://?daddr=\(restaurant.latitude),\(restaurant.longitude)")
        if let url {
            openURL(url)
        }
    }

    private func detailRow(icon: String, title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(AppColors.orangePrimary)
                .font(AppFonts.body(14, weight: .bold))
            Text(title)
                .foregroundStyle(AppColors.textSecondary)
                .font(AppFonts.body(14, weight: .semibold))
                .lineLimit(2)
        }
        .padding(12)
        .cinematicCard(cornerRadius: 14)
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(AppFonts.display(12, weight: .heavy))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 999))
            .overlay(
                RoundedRectangle(cornerRadius: 999)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
    }

    private func digitsOnly(_ input: String) -> String {
        input.filter { $0.isNumber }
    }
}

#Preview {
    NavigationStack {
        DetailView(
            restaurant: Restaurant(
                id: "1",
                name: "Midnight Ramen",
                address: "123 Noir Street",
                rating: 4.6,
                priceLevel: 2,
                isOpenNow: true,
                cuisine: "Japanese",
                photoReference: nil,
                phoneNumber: "(555) 555-5555",
                website: "https://example.com",
                weekdayHours: ["Mon: 11:00 AM – 9:00 PM"],
                latitude: 0,
                longitude: 0,
                distanceMiles: 1.2,
                isFavorited: false
            )
        )
        .environmentObject(FavoritesManager())
    }
}
