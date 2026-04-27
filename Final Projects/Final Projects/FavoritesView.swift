import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject private var favorites: FavoritesManager
    @State private var showClearConfirmation: Bool = false
    @State private var isSelectingToDelete: Bool = false
    @State private var selectedIDs: Set<String> = []
    @State private var showDeleteConfirmation: Bool = false

    var body: some View {
        ZStack {
            CinematicBackdrop().ignoresSafeArea()

            if favorites.favorites.isEmpty {
                emptyState
            } else {
                favoritesList
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog(
            "Clear all favorites?",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear All", role: .destructive) {
                let items = favorites.favorites
                items.forEach { favorites.toggleFavorite($0) }
            }
        }
        .confirmationDialog(
            "Delete selected favorites?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                let toRemove = favorites.favorites.filter { selectedIDs.contains($0.id) }
                toRemove.forEach { favorites.toggleFavorite($0) }
                selectedIDs.removeAll()
                isSelectingToDelete = false
            }
        }
    }

    private var favoritesList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                LazyVStack(spacing: 10) {
                    ForEach(favorites.favorites) { restaurant in
                        if isSelectingToDelete {
                            Button {
                                toggleSelection(for: restaurant)
                            } label: {
                                FavoriteRow(
                                    restaurant: restaurant,
                                    isSelecting: true,
                                    isSelected: selectedIDs.contains(restaurant.id)
                                )
                            }
                            .buttonStyle(.plain)
                        } else {
                            NavigationLink(value: restaurant) {
                                FavoriteRow(
                                    restaurant: restaurant,
                                    isSelecting: false,
                                    isSelected: false
                                )
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Remove from Favorites", role: .destructive) {
                                    favorites.toggleFavorite(restaurant)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .safeAreaPadding(.top, 18)
            .safeAreaPadding(.bottom, 24)
            .frame(maxWidth: 560, alignment: .center)
        }
        .scrollIndicators(.hidden)
    }

    private var emptyState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                VStack(alignment: .leading, spacing: 12) {
                    Text("Nothing saved yet")
                        .font(AppFonts.display(22, weight: .heavy))
                        .foregroundStyle(AppColors.textPrimary)

                    Text("Swipe through picks and hit Save to pin places you want to try later.")
                        .font(AppFonts.body(13, weight: .semibold))
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .cinematicCard(cornerRadius: 22)
                .frame(maxWidth: 520)
            }
            .padding(.horizontal, 20)
            .safeAreaPadding(.top, 18)
            .safeAreaPadding(.bottom, 24)
            .frame(maxWidth: 560, alignment: .center)
        }
        .scrollIndicators(.hidden)
    }

    private var header: some View {
        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("FAVORITES")
                    .font(AppFonts.display(12, weight: .heavy))
                    .tracking(2)
                    .foregroundStyle(AppColors.orangeSecondary)

                Text("Saved picks")
                    .font(AppFonts.display(32, weight: .heavy))
                    .foregroundStyle(AppColors.textPrimary)

                Group {
                    if isSelectingToDelete {
                        Text("\(selectedIDs.count) selected • Tap rows to select")
                    } else {
                        Text("\(favorites.favorites.count) place\(favorites.favorites.count == 1 ? "" : "s") • Tap a row for details")
                    }
                }
                .font(AppFonts.body(13, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)
            }

            Spacer(minLength: 0)

            if !favorites.favorites.isEmpty {
                if isSelectingToDelete {
                    VStack(alignment: .trailing, spacing: 10) {
                        Button {
                            showDeleteConfirmation = true
                        } label: {
                            Text(selectedIDs.isEmpty ? "Delete" : "Delete (\(selectedIDs.count))")
                                .font(AppFonts.display(13, weight: .heavy))
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(AppColors.closedRed.opacity(selectedIDs.isEmpty ? 0.35 : 0.85))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(AppColors.cardBorder, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(selectedIDs.isEmpty)

                        Button("Done") {
                            isSelectingToDelete = false
                            selectedIDs.removeAll()
                        }
                        .font(AppFonts.display(13, weight: .heavy))
                        .buttonStyle(GhostCinematicButtonStyle())
                    }
                } else {
                    VStack(alignment: .trailing, spacing: 10) {
                        Button("Select") {
                            isSelectingToDelete = true
                            selectedIDs.removeAll()
                        }
                        .font(AppFonts.display(13, weight: .heavy))
                        .buttonStyle(GhostCinematicButtonStyle())

                        Button("Clear") {
                            showClearConfirmation = true
                        }
                        .font(AppFonts.display(13, weight: .heavy))
                        .buttonStyle(GhostCinematicButtonStyle())
                    }
                }
            }
        }
        .padding(16)
        .cinematicCard(cornerRadius: 22)
        .frame(maxWidth: 520)
    }

    private func toggleSelection(for restaurant: Restaurant) {
        if selectedIDs.contains(restaurant.id) {
            selectedIDs.remove(restaurant.id)
        } else {
            selectedIDs.insert(restaurant.id)
        }
    }
}

private struct FavoriteRow: View {
    let restaurant: Restaurant
    let isSelecting: Bool
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(restaurant.name)
                    .font(AppFonts.display(16, weight: .heavy))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(2)

                Text("\(restaurant.cuisine) • \(restaurant.priceSymbols)")
                    .font(AppFonts.body(12, weight: .semibold))
                    .foregroundStyle(AppColors.orangeSecondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(String(format: "%.1f", restaurant.rating))
                        .foregroundStyle(AppColors.orangeSecondary)
                        .font(AppFonts.display(12, weight: .heavy))

                    Text(restaurant.isOpenNow ? "Open" : "Closed")
                        .foregroundStyle(restaurant.isOpenNow ? AppColors.openGreen : AppColors.closedRed)
                        .font(AppFonts.display(12, weight: .heavy))

                    if let distance = restaurant.distanceLabel {
                        Text("•")
                            .foregroundStyle(AppColors.textSecondary)
                        Text(distance)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                .font(AppFonts.body(12, weight: .semibold))

            }

            Spacer(minLength: 0)

            if isSelecting {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(isSelected ? AppColors.orangeSecondary : Color.white.opacity(0.25))
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppColors.textSecondary.opacity(0.8))
        }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(AppColors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(isSelected ? AppColors.orangeSecondary : AppColors.cardBorder, lineWidth: isSelected ? 2 : 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18))
    }
}

#Preview {
    NavigationStack {
        FavoritesView()
            .environmentObject(FavoritesManager())
    }
}
