import SwiftUI
import CoreLocation
import UIKit

struct SurpriseView: View {
    @EnvironmentObject private var favorites: FavoritesManager
    @EnvironmentObject private var model: RestaurantSearchViewModel
    @Environment(\.openURL) private var openURL

    let onGoToSearch: () -> Void

    @StateObject private var locationManager = LocationManager()

    @State private var isGenerating: Bool = false
    @State private var pickedRestaurant: Restaurant?
    @State private var statusMessage: String? = "Tap Generate to get a pick nearby."
    @State private var shuffleToken: Int = 0

    var body: some View {
        ZStack {
            CinematicBackdrop().ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    content
                }
                .frame(maxWidth: 560, alignment: .center)
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear {
            locationManager.requestPermissionIfNeeded()
            Task { await generateIfPossible() }
        }
        .onChange(of: locationManager.authorizationStatus) { _, _ in
            Task { await generateIfPossible() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SURPRISE")
                .font(AppFonts.display(12, weight: .heavy))
                .tracking(2)
                .foregroundStyle(AppColors.orangeSecondary)

            Text("Tonight’s pick")
                .font(AppFonts.display(34, weight: .heavy))
                .foregroundStyle(AppColors.textPrimary)

            Text(subtitleText)
                .font(AppFonts.body(13, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                statusPill(text: locationStatusText, systemImage: locationStatusIcon)

                if isGenerating {
                    statusPill(text: "Finding…", systemImage: "sparkles")
                } else if let statusMessage, !statusMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    statusPill(text: statusMessage, systemImage: "sparkles")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var content: some View {
        Group {
            if GOOGLE_PLACES_API_KEY == "YOUR_KEY_HERE" {
                apiKeyCard
            } else if isLocationDenied {
                deniedCard
            } else if !hasLocationAccess {
                permissionCard
            } else {
                pickPanel
            }
        }
    }

    private var apiKeyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Google Places API key not set")
                .font(AppFonts.display(18, weight: .heavy))
                .foregroundStyle(AppColors.textPrimary)

            Text("Add it in Constants.swift to enable nearby discovery.")
                .font(AppFonts.body(13, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)

            Button {
                onGoToSearch()
            } label: {
                Text("Go to Search")
                    .font(AppFonts.display(16, weight: .heavy))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(PrimaryCinematicButtonStyle())
        }
        .padding(18)
        .cinematicCard(cornerRadius: 22)
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Turn on location to generate nearby picks")
                .font(AppFonts.display(18, weight: .heavy))
                .foregroundStyle(AppColors.textPrimary)

            Text("We only use it to find restaurants near you.")
                .font(AppFonts.body(13, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)

            if let error = locationManager.errorMessage {
                Text(error)
                    .font(AppFonts.body(12, weight: .semibold))
                    .foregroundStyle(AppColors.closedRed)
            }

            HStack(spacing: 12) {
                Button {
                    locationManager.requestPermissionIfNeeded()
                } label: {
                    Label("Enable Location", systemImage: "location.fill")
                        .font(AppFonts.display(16, weight: .heavy))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(PrimaryCinematicButtonStyle())

                Button {
                    onGoToSearch()
                } label: {
                    Text("Use Search")
                        .font(AppFonts.display(16, weight: .heavy))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(GhostCinematicButtonStyle())
            }
        }
        .padding(18)
        .cinematicCard(cornerRadius: 22)
    }

    private var deniedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Location is off")
                .font(AppFonts.display(18, weight: .heavy))
                .foregroundStyle(AppColors.textPrimary)

            Text(locationManager.errorMessage ?? "Enable location in Settings to generate nearby picks.")
                .font(AppFonts.body(13, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                } label: {
                    Text("Open Settings")
                        .font(AppFonts.display(16, weight: .heavy))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(GhostCinematicButtonStyle())

                Button {
                    onGoToSearch()
                } label: {
                    Text("Use Search")
                        .font(AppFonts.display(16, weight: .heavy))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(PrimaryCinematicButtonStyle())
            }
        }
        .padding(18)
        .cinematicCard(cornerRadius: 22)
    }

    private var pickPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("PICK")
                    .font(AppFonts.display(12, weight: .heavy))
                    .tracking(2)
                    .foregroundStyle(AppColors.orangeSecondary)
                Spacer()
                if isGenerating {
                    ProgressView()
                        .tint(AppColors.orangePrimary)
                }
            }

            if let pickedRestaurant {
                NavigationLink(value: pickedRestaurant) {
                    pickCard(for: pickedRestaurant)
                }
                .buttonStyle(.plain)

                HStack(spacing: 12) {
                    Button {
                        shuffleToken &+= 1
                        shufflePick()
                    } label: {
                        Label("Shuffle", systemImage: "dice.fill")
                            .font(AppFonts.display(16, weight: .heavy))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(GhostCinematicButtonStyle())
                    .modifier(ShuffleHaptics(trigger: shuffleToken))

                    Button {
                        favorites.toggleFavorite(pickedRestaurant)
                    } label: {
                        Label(favorites.isFavorited(pickedRestaurant) ? "Saved" : "Save", systemImage: favorites.isFavorited(pickedRestaurant) ? "heart.fill" : "heart")
                            .font(AppFonts.display(16, weight: .heavy))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(PrimaryCinematicButtonStyle())
                }

                HStack(spacing: 12) {
                    Button {
                        openDirections(to: pickedRestaurant)
                    } label: {
                        Label("Directions", systemImage: "map")
                            .font(AppFonts.display(15, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(GhostCinematicButtonStyle())

                    Menu {
                        Button("Refresh Nearby") {
                            Task { await forceRefresh() }
                        }

                        Button("Change Filters") {
                            onGoToSearch()
                        }
                    } label: {
                        Label("More", systemImage: "ellipsis")
                            .font(AppFonts.display(15, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(GhostCinematicButtonStyle())
                }
            } else {
                emptyPickCard

                Button {
                    Task { await forceRefresh() }
                } label: {
                    Text("Generate")
                        .font(AppFonts.display(16, weight: .heavy))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(PrimaryCinematicButtonStyle())

                Button {
                    onGoToSearch()
                } label: {
                    Text("Prefer filters? Use Search")
                        .font(AppFonts.body(14, weight: .semibold))
                        .foregroundStyle(AppColors.orangeSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .cinematicCard(cornerRadius: 22)
    }

    private func pickCard(for restaurant: Restaurant) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            RestaurantImage(
                photoReference: restaurant.photoReference,
                height: 210,
                cornerRadius: 18,
                overlayStyle: .bottomFade(opacity: 0.50)
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(restaurant.name)
                    .font(AppFonts.display(22, weight: .heavy))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
                    .frame(minHeight: 28, alignment: .topLeading)

                Text("\(restaurant.cuisine) • \(restaurant.priceSymbols)")
                    .font(AppFonts.body(14, weight: .semibold))
                    .foregroundStyle(AppColors.orangeSecondary)
                    .lineLimit(1)

                HStack(spacing: 10) {
                    Label(String(format: "%.1f", restaurant.rating), systemImage: "star.fill")
                        .foregroundStyle(AppColors.orangeSecondary)

                    Text(restaurant.isOpenNow ? "Open" : "Closed")
                        .foregroundStyle(restaurant.isOpenNow ? AppColors.openGreen : AppColors.closedRed)
                        .font(AppFonts.body(14, weight: .bold))

                    if let distance = restaurant.distanceLabel {
                        Text(distance)
                            .foregroundStyle(AppColors.textSecondary)
                            .font(AppFonts.body(14, weight: .semibold))
                    }
                }
                .font(AppFonts.body(14, weight: .semibold))

                Text(restaurant.address)
                    .foregroundStyle(AppColors.textSecondary)
                    .font(AppFonts.body(13, weight: .regular))
                    .lineLimit(2)
                    .frame(minHeight: 34, alignment: .topLeading)
            }
            .padding(.horizontal, 4)
        }
    }

    private var emptyPickCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 210)

                Image(systemName: "fork.knife")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(AppColors.orangePrimary)
            }

            Text("No pick yet")
                .font(AppFonts.display(20, weight: .heavy))
                .foregroundStyle(AppColors.textPrimary)

            Text("Tap Generate to grab one nearby. You can shuffle or save after.")
                .font(AppFonts.body(13, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func statusPill(text: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .bold))
            Text(text)
                .lineLimit(1)
        }
        .font(AppFonts.display(12, weight: .heavy))
        .foregroundStyle(AppColors.textPrimary)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 999))
        .overlay(
            RoundedRectangle(cornerRadius: 999)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private var hasLocationAccess: Bool {
        locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways
    }

    private var isLocationDenied: Bool {
        locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted
    }

    private var locationStatusText: String {
        if hasLocationAccess { return "Near you" }
        if isLocationDenied { return "Location off" }
        return "Needs location"
    }

    private var locationStatusIcon: String {
        if hasLocationAccess { return "location.fill" }
        if isLocationDenied { return "location.slash" }
        return "location"
    }

    private var subtitleText: String {
        hasLocationAccess ? "We’ll pull one nearby. Tap the card for details." : "Enable location for instant nearby picks — or use Search."
    }

    private func generateIfPossible() async {
        guard pickedRestaurant == nil else { return }
        guard hasLocationAccess else { return }
        await forceRefresh()
    }

    private func forceRefresh() async {
        guard !isGenerating else { return }
        isGenerating = true
        statusMessage = "Finding nearby restaurants…"
        defer { isGenerating = false }

        do {
            let coordinate = try await locationManager.requestOneShotLocation()
            await model.searchUsingCoordinate(coordinate, label: "Near you")

            if let errorMessage = model.errorMessage {
                pickedRestaurant = nil
                statusMessage = errorMessage
                return
            }

            let candidates = model.filteredRestaurants
            if candidates.isEmpty {
                pickedRestaurant = nil
                statusMessage = "No results — try loosening filters in Search."
            } else {
                pickedRestaurant = candidates.randomElement()
                statusMessage = "Tap the card for details."
            }
        } catch {
            pickedRestaurant = nil
            statusMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn’t get location."
        }
    }

    private func shufflePick() {
        let candidates = model.filteredRestaurants
        guard !candidates.isEmpty else {
            pickedRestaurant = nil
            return
        }

        if candidates.count == 1 {
            pickedRestaurant = candidates.first
            return
        }

        let currentID = pickedRestaurant?.id
        let next = candidates.filter { $0.id != currentID }.randomElement() ?? candidates.randomElement()
        withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
            pickedRestaurant = next
        }
        statusMessage = "Tap the card for details."
    }

    private func openDirections(to restaurant: Restaurant) {
        let url = URL(string: "maps://?daddr=\(restaurant.latitude),\(restaurant.longitude)")
        if let url {
            openURL(url)
        }
    }
}

private struct ShuffleHaptics: ViewModifier {
    let trigger: Int

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.sensoryFeedback(.impact(flexibility: .soft, intensity: 0.8), trigger: trigger)
        } else {
            content
        }
    }
}

#Preview {
    NavigationStack {
        SurpriseView(onGoToSearch: {})
            .environmentObject(FavoritesManager())
            .environmentObject(RestaurantSearchViewModel(service: RestaurantService(apiKey: GOOGLE_PLACES_API_KEY)))
    }
}
