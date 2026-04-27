import SwiftUI
import CoreLocation
import Combine

@MainActor
final class RestaurantSearchViewModel: ObservableObject {
    enum ResultsMode: String {
        case swipe
        case list
    }

    enum PriceFilter: String, CaseIterable, Identifiable {
        case dollar = "$"
        case two = "$$"
        case three = "$$$"
        case four = "$$$$"
        case any = "Any"

        var id: String { rawValue }

        var level: Int? {
            switch self {
            case .dollar: 1
            case .two: 2
            case .three: 3
            case .four: 4
            case .any: nil
            }
        }
    }

    enum SortOption: String, CaseIterable, Identifiable {
        case rating = "Rating"
        case distance = "Distance"
        case priceLow = "Price (low to high)"
        case priceHigh = "Price (high to low)"

        var id: String { rawValue }
    }

    enum Vibe: String, CaseIterable, Identifiable {
        case any = "Surprise me"
        case cozy = "Cozy"
        case lively = "Lively"
        case romantic = "Romantic"
        case lateNight = "Late Night"
        case brunch = "Brunch"

        var id: String { rawValue }

        var keywords: [String] {
            switch self {
            case .any:
                return []
            case .cozy:
                return ["cozy", "intimate"]
            case .lively:
                return ["lively", "buzzing"]
            case .romantic:
                return ["romantic", "date night"]
            case .lateNight:
                return ["late night"]
            case .brunch:
                return ["brunch"]
            }
        }
    }

    enum Dietary: String, CaseIterable, Identifiable {
        case none = "No preference"
        case vegetarian = "Vegetarian"
        case vegan = "Vegan"
        case glutenFree = "Gluten-free"

        var id: String { rawValue }

        var keyword: String? {
            switch self {
            case .none:
                return nil
            case .vegetarian:
                return "vegetarian"
            case .vegan:
                return "vegan"
            case .glutenFree:
                return "gluten free"
            }
        }
    }

    let cuisines: [String] = [
        "All",
        "Mexican",
        "Italian",
        "Chinese",
        "Japanese",
        "American",
        "Indian",
        "Thai",
        "Mediterranean",
        "Fast Food"
    ]

    @Published var locationQuery: String = ""
    @Published private(set) var locationPredictions: [RestaurantService.LocationPrediction] = []
    @Published private(set) var selectedLocationCoordinate: CLLocationCoordinate2D?
    @Published private(set) var selectedLocationPlaceID: String?
    @Published var selectedCuisine: String = "All"
    @Published var selectedPrice: PriceFilter = .any
    @Published var openNowOnly: Bool = false
    @Published var radiusMiles: Double = 10.0
    @Published var sortOption: SortOption = .rating
    @Published var resultsMode: ResultsMode = .swipe
    @Published var selectedVibe: Vibe = .any
    @Published var dietary: Dietary = .none
    @Published var partySize: Int = 2
    @Published var partySegment: PartySegment = .two

    @Published private(set) var isLoading: Bool = false
    @Published private(set) var restaurants: [Restaurant] = []
    @Published private(set) var lastSearchCoordinate: CLLocationCoordinate2D?
    @Published private(set) var lastSearchLabel: String = ""
    @Published private(set) var hasSearched: Bool = false
    @Published var errorMessage: String?

    private let service: RestaurantService
    private var predictionsTask: Task<Void, Never>?

    enum PartySegment: String, CaseIterable, Identifiable {
        case one = "1"
        case two = "2"
        case threeToFour = "3–4"
        case fivePlus = "5+"

        var id: String { rawValue }

        var size: Int {
            switch self {
            case .one: 1
            case .two: 2
            case .threeToFour: 4
            case .fivePlus: 6
            }
        }

        var label: String {
            switch self {
            case .one: "1 person"
            case .two: "2 people"
            case .threeToFour: "3–4 people"
            case .fivePlus: "5+ people"
            }
        }
    }

    init(service: RestaurantService) {
        self.service = service
    }

    var filteredRestaurants: [Restaurant] {
        var filtered = restaurants

        if selectedCuisine != "All" {
            filtered = filtered.filter { $0.cuisine == selectedCuisine }
        }

        if let level = selectedPrice.level {
            filtered = filtered.filter { $0.priceLevel == level }
        }

        if openNowOnly {
            filtered = filtered.filter { $0.isOpenNow }
        }

        filtered = filtered.filter {
            guard let distance = $0.distanceMiles else { return true }
            return distance <= radiusMiles
        }

        switch sortOption {
        case .rating:
            filtered.sort { $0.rating > $1.rating }
        case .distance:
            filtered.sort {
                switch ($0.distanceMiles, $1.distanceMiles) {
                case let (a?, b?):
                    return a < b
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                case (nil, nil):
                    return $0.name < $1.name
                }
            }
        case .priceLow:
            filtered.sort {
                let a = ($0.priceLevel == 0) ? Int.max : $0.priceLevel
                let b = ($1.priceLevel == 0) ? Int.max : $1.priceLevel
                return a < b
            }
        case .priceHigh:
            filtered.sort {
                let a = ($0.priceLevel == 0) ? -1 : $0.priceLevel
                let b = ($1.priceLevel == 0) ? -1 : $1.priceLevel
                return a > b
            }
        }

        filtered = filtered.filter { restaurant in
            guard restaurant.photoReference != nil else { return false }
            guard let aspect = restaurant.photoAspectRatio else { return true }
            return aspect >= 0.65 && aspect <= 2.20
        }

        return filtered
    }

    func search() async {
        errorMessage = nil
        isLoading = true
        restaurants = []
        hasSearched = true

        do {
            partySize = partySegment.size
            let keyword = keywordString()
            let response = try await service.searchRestaurants(
                near: locationQuery,
                coordinate: selectedLocationCoordinate,
                radiusMiles: radiusMiles,
                keyword: keyword,
                openNow: openNowOnly,
                queryFallback: googleTextSearchQuery()
            )
            lastSearchCoordinate = response.coordinate
            lastSearchLabel = locationQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            restaurants = response.restaurants
            resultsMode = .swipe

            if restaurants.isEmpty {
                errorMessage = nil
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Something went wrong. Please try again."
        }

        isLoading = false
    }

    func searchUsingCoordinate(_ coordinate: CLLocationCoordinate2D, label: String = "Near you") async {
        errorMessage = nil
        isLoading = true
        restaurants = []
        hasSearched = true

        do {
            partySize = partySegment.size
            let keyword = keywordString()
            let response = try await service.searchRestaurants(
                near: label,
                coordinate: coordinate,
                radiusMiles: radiusMiles,
                keyword: keyword,
                openNow: openNowOnly,
                queryFallback: "restaurants near me"
            )
            lastSearchCoordinate = response.coordinate
            lastSearchLabel = label
            restaurants = response.restaurants
            resultsMode = .swipe
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Something went wrong. Please try again."
        }

        isLoading = false
    }

    func onLocationQueryChanged() {
        selectedLocationCoordinate = nil
        selectedLocationPlaceID = nil

        predictionsTask?.cancel()
        let input = locationQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard input.count >= 3 else {
            locationPredictions = []
            return
        }

        predictionsTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            do {
                let predictions = try await service.autocompleteLocations(input: input)
                guard !Task.isCancelled else { return }
                locationPredictions = Array(predictions.prefix(6))
            } catch {
                locationPredictions = []
            }
        }
    }

    func selectPrediction(_ prediction: RestaurantService.LocationPrediction) async {
        locationQuery = prediction.description
        selectedLocationPlaceID = prediction.id
        locationPredictions = []

        do {
            selectedLocationCoordinate = try await service.coordinateForPlaceID(prediction.id)
        } catch {
            selectedLocationCoordinate = nil
        }
    }

    func clearPredictions() {
        locationPredictions = []
    }

    func googleTextSearchQuery() -> String {
        let location = locationQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        var tokens: [String] = []

        if selectedCuisine != "All" {
            tokens.append(selectedCuisine.lowercased())
        }

        tokens.append(contentsOf: selectedVibe.keywords)

        if let dietaryKeyword = dietary.keyword {
            tokens.append(dietaryKeyword)
        }

        tokens.append(contentsOf: partyKeywords(for: partySize))

        let prefix = tokens.isEmpty ? "" : "\(tokens.joined(separator: " ")) "
        return "\(prefix)restaurants near \(location)"
    }

    func keywordString() -> String? {
        var tokens: [String] = []
        if selectedCuisine != "All" { tokens.append(selectedCuisine.lowercased()) }
        tokens.append(contentsOf: selectedVibe.keywords)
        if let dietaryKeyword = dietary.keyword { tokens.append(dietaryKeyword) }
        tokens.append(contentsOf: partyKeywords(for: partySize))

        let keyword = tokens.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return keyword.isEmpty ? nil : keyword
    }

    private func partyKeywords(for size: Int) -> [String] {
        switch size {
        case ..<3:
            return []
        case 3...4:
            return ["good for groups"]
        default:
            return ["group friendly"]
        }
    }

    func surpriseRestaurant() -> Restaurant? {
        filteredRestaurants.randomElement()
    }

    func resetFilters() {
        selectedCuisine = "All"
        selectedPrice = .any
        openNowOnly = false
        radiusMiles = 10.0
        sortOption = .rating
        selectedVibe = .any
        dietary = .none
        partySegment = .two
    }

    func clearResults() {
        restaurants = []
        errorMessage = nil
        lastSearchCoordinate = nil
        lastSearchLabel = ""
        hasSearched = false
        clearPredictions()
    }
}

struct SearchView: View {
    @EnvironmentObject private var model: RestaurantSearchViewModel

    let onNavigateToDetail: (Restaurant) -> Void
    let onShowFavorites: () -> Void

    @FocusState private var locationFieldFocused: Bool
    @State private var filtersExpanded: Bool = false

    var body: some View {
        GeometryReader { proxy in
            let minDeckHeight: CGFloat = 420
            let availableForControls = max(220, proxy.size.height - minDeckHeight)
            let maxControlsHeight = min(
                availableForControls,
                filtersExpanded ? 560 : 300
            )

            ZStack {
                CinematicBackdrop().ignoresSafeArea()

                VStack(spacing: 0) {
                    controlsHeader(maxHeight: maxControlsHeight)

                    Divider()
                        .overlay(AppColors.cardBorder)

                    deckArea
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .onAppear {
            model.resultsMode = .swipe
        }
    }

    private func controlsHeader(maxHeight: CGFloat) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SWIPE & SEARCH")
                            .font(AppFonts.display(12, weight: .heavy))
                            .tracking(2)
                            .foregroundStyle(AppColors.orangeSecondary)

                        Text("Pick a location, refine filters, then swipe.")
                            .font(AppFonts.body(13, weight: .semibold))
                            .foregroundStyle(AppColors.textSecondary)

                        Text(activeFiltersSummary)
                            .font(AppFonts.body(12, weight: .semibold))
                            .foregroundStyle(AppColors.textSecondary.opacity(0.90))
                            .lineLimit(2)
                            .padding(.top, 6)
                    }

                    Spacer()
                }

                controlsCard
            }
            .padding(.horizontal, 20)
            .safeAreaPadding(.top, 12)
            .padding(.bottom, 8)
            .frame(maxWidth: 560, alignment: .center)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .frame(maxHeight: maxHeight)
        .clipped()
        .animation(.spring(response: 0.32, dampingFraction: 0.88), value: filtersExpanded)
    }

    private var activeFiltersSummary: String {
        var parts: [String] = []
        parts.append(model.selectedCuisine == "All" ? "Any cuisine" : model.selectedCuisine)
        parts.append(model.selectedPrice == .any ? "Any price" : model.selectedPrice.rawValue)
        parts.append(String(format: "%.1f mi", model.radiusMiles))
        if model.openNowOnly {
            parts.append("Open now")
        }
        return parts.joined(separator: " • ")
    }

    private var controlsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            locationSection

            Divider()
                .overlay(AppColors.cardBorder)

            DisclosureGroup(isExpanded: $filtersExpanded) {
                quickFilters
                    .padding(.top, 10)
            } label: {
                HStack {
                    Text("Refine filters")
                        .font(AppFonts.display(15, weight: .heavy))
                        .foregroundStyle(AppColors.textPrimary)
                    Spacer()
                    Text(filtersExpanded ? "Hide" : "Show")
                        .font(AppFonts.display(12, weight: .heavy))
                        .foregroundStyle(AppColors.orangeSecondary)
                }
            }
        }
        .padding(14)
        .cinematicCard(cornerRadius: 18)
        .frame(maxWidth: 520)
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                TextField("City, neighborhood, or ZIP", text: $model.locationQuery)
                    .font(AppFonts.body(15, weight: .semibold))
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .focused($locationFieldFocused)
                    .submitLabel(.search)
                    .onChange(of: model.locationQuery) { _, _ in
                        model.onLocationQueryChanged()
                    }
                    .onSubmit {
                        Task { await runSearch() }
                    }
                    .foregroundStyle(AppColors.textPrimary)
            }
            .padding(14)
            .background(Color.black.opacity(0.18))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))

            if !model.locationPredictions.isEmpty {
                VStack(spacing: 8) {
                    ForEach(Array(model.locationPredictions.prefix(4))) { prediction in
                        Button {
                            Task { await model.selectPrediction(prediction) }
                        } label: {
                            HStack(spacing: 10) {
                                Text(prediction.description)
                                    .font(AppFonts.body(13, weight: .semibold))
                                    .foregroundStyle(AppColors.textPrimary)
                                    .lineLimit(2)
                                Spacer()
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(Color.white.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(AppColors.cardBorder, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var quickFilters: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Cuisine")
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                Picker("Cuisine", selection: $model.selectedCuisine) {
                    ForEach(model.cuisines, id: \.self) { cuisine in
                        Text(cuisine).tag(cuisine)
                    }
                }
                .pickerStyle(.menu)
                .tint(AppColors.orangeSecondary)
            }

            Picker("Price", selection: $model.selectedPrice) {
                ForEach(RestaurantSearchViewModel.PriceFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .tint(AppColors.orangePrimary)

            Toggle("Open now", isOn: $model.openNowOnly)
                .tint(AppColors.orangePrimary)
                .foregroundStyle(AppColors.textPrimary)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Radius")
                        .foregroundStyle(AppColors.textPrimary)
                    Spacer()
                    Text(String(format: "%.1f mi", model.radiusMiles))
                        .foregroundStyle(AppColors.textSecondary)
                }
                Slider(value: $model.radiusMiles, in: 0.5...10.0, step: 0.5)
                    .tint(AppColors.orangePrimary)
            }
        }
    }

    @ViewBuilder
    private var deckArea: some View {
        if model.isLoading {
            VStack(spacing: 12) {
                ProgressView()
                    .tint(AppColors.orangePrimary)
                Text("Finding restaurants…")
                    .foregroundStyle(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage = model.errorMessage, model.filteredRestaurants.isEmpty {
            VStack(spacing: 14) {
                Text("Couldn’t load restaurants")
                    .font(AppFonts.display(18, weight: .heavy))
                    .foregroundStyle(AppColors.textPrimary)

                Text(errorMessage)
                    .foregroundStyle(AppColors.closedRed.opacity(0.95))
                    .font(AppFonts.body(13, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)

                Button("Retry") { Task { await runSearch() } }
                    .font(AppFonts.display(15, weight: .heavy))
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .buttonStyle(PrimaryCinematicButtonStyle())
            }
            .padding(18)
            .frame(maxWidth: 520)
            .cinematicCard(cornerRadius: 22)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.filteredRestaurants.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "fork.knife")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(AppColors.orangePrimary)

                Text(model.hasSearched ? "No matches — loosen your filters." : "Enter a location to start.")
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            SwipeView(
                restaurants: model.filteredRestaurants,
                onShowFavorites: onShowFavorites,
                isControlsExpanded: filtersExpanded
            )
        }
    }

    @ViewBuilder
    private var contentArea: some View {
        if model.isLoading {
            VStack(spacing: 12) {
                ProgressView()
                    .tint(AppColors.orangePrimary)
                Text("Finding restaurants...")
                    .foregroundStyle(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage = model.errorMessage, model.restaurants.isEmpty {
            VStack(spacing: 14) {
                Text("Couldn’t load restaurants")
                    .font(AppFonts.display(18, weight: .heavy))
                    .foregroundStyle(AppColors.textPrimary)

                Text(errorMessage)
                    .foregroundStyle(Color.red.opacity(0.92))
                    .font(AppFonts.body(13, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)

                Button("Retry") {
                    Task { await runSearch() }
                }
                .font(AppFonts.display(15, weight: .heavy))
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
                .buttonStyle(PrimaryCinematicButtonStyle())
            }
            .padding(18)
            .frame(maxWidth: 520)
            .cinematicCard(cornerRadius: 22)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.restaurants.isEmpty, model.hasSearched {
            VStack(spacing: 10) {
                Text("No restaurants found — try adjusting your filters")
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.restaurants.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "fork.knife")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(AppColors.orangePrimary)

                Text("Enter a location to discover restaurants near you")
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.filteredRestaurants.isEmpty {
            VStack(spacing: 12) {
                Text("Filters are too tight")
                    .font(AppFonts.display(18, weight: .heavy))
                    .foregroundStyle(AppColors.textPrimary)

                Text("We found \(model.restaurants.count) places, but your filters removed them all. Try clearing filters or increasing the radius.")
                    .foregroundStyle(AppColors.textSecondary)
                    .font(AppFonts.body(13, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)

                HStack(spacing: 10) {
                    Button("Clear Filters") {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                            model.resetFilters()
                        }
                    }
                    .font(AppFonts.display(15, weight: .heavy))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .buttonStyle(PrimaryCinematicButtonStyle())

                    Button("Increase Radius") {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                            model.radiusMiles = min(model.radiusMiles + 5.0, 25.0)
                        }
                    }
                    .font(AppFonts.display(15, weight: .heavy))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .buttonStyle(GhostCinematicButtonStyle())
                }
            }
            .padding(18)
            .frame(maxWidth: 520)
            .cinematicCard(cornerRadius: 22)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            switch model.resultsMode {
            case .swipe:
                SwipeView(
                    restaurants: model.filteredRestaurants,
                    onShowFavorites: onShowFavorites
                )
            case .list:
                ResultsView(restaurants: model.filteredRestaurants, sortOption: $model.sortOption)
            }
        }
    }

    private func header(maxHeight: CGFloat) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(AppStrings.appTitle)
                    .font(AppFonts.display(34, weight: .heavy))
                    .foregroundStyle(AppColors.orangePrimary)
                    .padding(.top, 10)

                locationInput

                findButtonRow

                filtersSection

                surpriseButton
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
        }
        .scrollIndicators(.hidden)
        .frame(maxHeight: maxHeight)
    }

    private func homeHeader(maxHeight: CGFloat, onRefine: @escaping () -> Void) -> some View {
        Group {
            if model.isLoading {
                LoadingHero()
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 12)
            } else if model.restaurants.isEmpty, model.hasSearched {
                ResultsHero(
                    location: model.lastSearchLabel.isEmpty ? model.locationQuery : model.lastSearchLabel,
                    count: 0,
                    onRefine: onRefine
                )
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 12)
            } else {
                ResultsHero(
                    location: model.lastSearchLabel.isEmpty ? model.locationQuery : model.lastSearchLabel,
                    count: model.filteredRestaurants.count,
                    onRefine: onRefine
                )
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 12)
            }
        }
        .frame(maxHeight: maxHeight)
    }

    private var locationInput: some View {
        TextField("City, neighborhood, or ZIP", text: $model.locationQuery)
            .font(AppFonts.body(15, weight: .semibold))
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .focused($locationFieldFocused)
            .submitLabel(.search)
            .onChange(of: model.locationQuery) { _, _ in
                model.onLocationQueryChanged()
            }
            .onSubmit {
                Task {
                    await runSearch()
                }
            }
            .padding(14)
            .background(AppColors.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .foregroundStyle(AppColors.textPrimary)
    }

    private var findButtonRow: some View {
        Button {
            Task {
                await runSearch()
            }
        } label: {
            HStack {
                Spacer()
                Text("Find Restaurants")
                    .font(AppFonts.display(16, weight: .bold))
                Spacer()
            }
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(AppColors.orangePrimary)
    }

    private var filtersSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Filters")
                .font(AppFonts.body(16, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary)

            cuisinePills

            Picker("Price", selection: $model.selectedPrice) {
                ForEach(RestaurantSearchViewModel.PriceFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .tint(AppColors.orangePrimary)

            Toggle("Open Now", isOn: $model.openNowOnly)
                .tint(AppColors.orangePrimary)
                .foregroundStyle(AppColors.textPrimary)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Distance")
                        .foregroundStyle(AppColors.textPrimary)
                    Spacer()
                    Text(String(format: "%.1f mi", model.radiusMiles))
                        .foregroundStyle(AppColors.textSecondary)
                }
                Slider(value: $model.radiusMiles, in: 0.5...10.0, step: 0.5)
                    .tint(AppColors.orangePrimary)
            }

            HStack {
                Text("Sort by")
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                Picker("Sort by", selection: $model.sortOption) {
                    ForEach(RestaurantSearchViewModel.SortOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .tint(AppColors.orangeSecondary)
            }
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var cuisinePills: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(model.cuisines, id: \.self) { cuisine in
                    Button {
                        model.selectedCuisine = cuisine
                    } label: {
                        Text(cuisine)
                            .font(AppFonts.body(14, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .foregroundStyle(model.selectedCuisine == cuisine ? Color.black : AppColors.textPrimary)
                            .background(model.selectedCuisine == cuisine ? AppColors.orangeSecondary : AppColors.background.opacity(0.9))
                            .overlay(
                                RoundedRectangle(cornerRadius: 999)
                                    .stroke(AppColors.cardBorder, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 999))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }

    private var surpriseButton: some View {
        Button {
            guard let restaurant = model.surpriseRestaurant() else { return }
            onNavigateToDetail(restaurant)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "dice")
                    .font(AppFonts.display(16, weight: .bold))
                Text("Surprise Me!")
                    .font(AppFonts.display(16, weight: .heavy))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(AppColors.orangeSecondary)
        .disabled(model.filteredRestaurants.isEmpty)
    }

    private var resultsToggle: some View {
        HStack(spacing: 12) {
            modeButton(title: "Swipe", mode: .swipe)
            modeButton(title: "List", mode: .list)
        }
    }

    private func modeButton(title: String, mode: RestaurantSearchViewModel.ResultsMode) -> some View {
        Button {
            model.resultsMode = mode
        } label: {
            Text(title)
                .font(AppFonts.body(14, weight: .bold))
                .foregroundStyle(model.resultsMode == mode ? Color.black : AppColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(model.resultsMode == mode ? AppColors.orangePrimary : AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.cardBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func runSearch() async {
        locationFieldFocused = false
        await model.search()
    }
}

private struct MagazineHome: View {
    @EnvironmentObject private var model: RestaurantSearchViewModel
    @FocusState var locationFieldFocused: Bool

    let onFind: () -> Void

    @State private var showLocationHint: Bool = false

    var body: some View {
        VStack(spacing: 18) {
            cover
            MagazineControls(locationFieldFocused: _locationFieldFocused, showLocationHint: $showLocationHint)
            ctaRow
        }
        .padding(.horizontal, 20)
        .safeAreaPadding(.top, 22)
        .safeAreaPadding(.bottom, 22)
        .background(CinematicBackdrop().ignoresSafeArea())
    }

    private var cover: some View {
        VStack(spacing: 10) {
            Text(AppStrings.appTitle.uppercased())
                .font(AppFonts.display(12, weight: .heavy))
                .tracking(2)
                .foregroundStyle(AppColors.orangeSecondary)

            Text("Tonight’s issue:")
                .font(AppFonts.body(14, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)

            Text("Restaurants worth the walk.")
                .font(AppFonts.display(34, weight: .heavy))
                .foregroundStyle(AppColors.textPrimary)
                .multilineTextAlignment(.center)

            if GOOGLE_PLACES_API_KEY == "YOUR_KEY_HERE" {
                apiKeyBanner
                    .frame(maxWidth: 520)
            }

            HStack(spacing: 8) {
                summaryChip(text: model.selectedCuisine == "All" ? "Any cuisine" : model.selectedCuisine, systemImage: "fork.knife")
                summaryChip(text: model.selectedVibe.rawValue, systemImage: "sparkles")
                summaryChip(text: model.partySegment.label, systemImage: "person.2.fill")
            }
        }
        .frame(maxWidth: 520)
    }

    private var apiKeyBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "key.fill")
                .font(AppFonts.body(14, weight: .bold))
                .foregroundStyle(AppColors.orangeSecondary)

            VStack(alignment: .leading, spacing: 4) {
                Text("Google Places API key not set")
                    .font(AppFonts.display(13, weight: .heavy))
                    .foregroundStyle(AppColors.textPrimary)
                Text("Add it in Constants.swift to enable live restaurant search.")
                    .font(AppFonts.body(12, weight: .semibold))
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()
        }
        .padding(12)
        .cinematicCard(cornerRadius: 16)
    }

    private func summaryChip(text: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .bold))
            Text(text)
                .font(AppFonts.display(12, weight: .heavy))
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 999))
        .overlay(
            RoundedRectangle(cornerRadius: 999)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        )
    }

    private var ctaRow: some View {
        HStack(spacing: 12) {
            Button {
                let location = model.locationQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                if location.isEmpty {
                    showLocationHint = true
                    locationFieldFocused = true
                    return
                }
                onFind()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(AppFonts.display(15, weight: .bold))
                    Text("Generate Picks")
                        .font(AppFonts.display(16, weight: .heavy))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(PrimaryCinematicButtonStyle())
            .opacity(model.locationQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.65 : 1.0)

            Button {
                model.resultsMode = .swipe
                let location = model.locationQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                if location.isEmpty {
                    showLocationHint = true
                    locationFieldFocused = true
                    return
                }
                onFind()
            } label: {
                Image(systemName: "dice.fill")
                    .font(AppFonts.display(16, weight: .heavy))
                    .frame(width: 54, height: 48)
            }
            .buttonStyle(GhostCinematicButtonStyle())
            .accessibilityLabel("Surprise Me")
            .opacity(model.locationQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.65 : 1.0)
        }
        .frame(maxWidth: 520)
    }
}

private struct MagazineControls: View {
    @EnvironmentObject private var model: RestaurantSearchViewModel
    @FocusState var locationFieldFocused: Bool
    @Binding var showLocationHint: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            MagazineSectionHeader(title: "WHERE")

            VStack(alignment: .leading, spacing: 8) {
                TextField("City, neighborhood, or ZIP", text: $model.locationQuery)
                    .font(AppFonts.body(15, weight: .semibold))
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .focused($locationFieldFocused)
                    .submitLabel(.search)
                    .onChange(of: model.locationQuery) { _, _ in
                        model.onLocationQueryChanged()
                    }
                    .padding(14)
                    .background(Color.black.opacity(0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppColors.cardBorder, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(AppColors.textPrimary)

                if !model.locationPredictions.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(model.locationPredictions) { prediction in
                            Button {
                                Task { await model.selectPrediction(prediction) }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "mappin.and.ellipse")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(AppColors.orangeSecondary)
                                    Text(prediction.description)
                                        .font(AppFonts.body(13, weight: .semibold))
                                        .foregroundStyle(AppColors.textPrimary)
                                        .lineLimit(2)
                                    Spacer()
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                .background(Color.white.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(AppColors.cardBorder, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 4)
                }

                if showLocationHint, model.locationQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Enter a location to search (city, neighborhood, or ZIP).")
                        .font(AppFonts.body(12, weight: .semibold))
                        .foregroundStyle(Color.red.opacity(0.9))
                }
            }
            .padding(16)
            .cinematicCard(cornerRadius: 22)

            MagazineSectionHeader(title: "WHO’S COMING")

            VStack(alignment: .leading, spacing: 10) {
                Picker("Party size", selection: $model.partySegment) {
                    ForEach(RestaurantSearchViewModel.PartySegment.allCases) { segment in
                        Text(segment.rawValue).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .tint(AppColors.orangePrimary)

                Text(model.partySegment.label)
                    .font(AppFonts.body(12, weight: .semibold))
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(16)
            .cinematicCard(cornerRadius: 22)

            MagazineSectionHeader(title: "THE FLAVOR")

            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(model.cuisines, id: \.self) { cuisine in
                        QuizPill(title: cuisine, isSelected: model.selectedCuisine == cuisine) {
                            model.selectedCuisine = cuisine
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .cinematicCard(cornerRadius: 22)

            MagazineSectionHeader(title: "THE MOOD")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(RestaurantSearchViewModel.Vibe.allCases) { vibe in
                    QuizTile(title: vibe.rawValue, isSelected: model.selectedVibe == vibe) {
                        model.selectedVibe = vibe
                    }
                }
            }
            .padding(16)
            .cinematicCard(cornerRadius: 22)

            MagazineSectionHeader(title: "THE RULES")

            VStack(alignment: .leading, spacing: 12) {
                Picker("Price", selection: $model.selectedPrice) {
                    ForEach(RestaurantSearchViewModel.PriceFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .tint(AppColors.orangePrimary)

                HStack {
                    Text("Dietary")
                        .foregroundStyle(AppColors.textPrimary)
                    Spacer()
                    Picker("Dietary", selection: $model.dietary) {
                        ForEach(RestaurantSearchViewModel.Dietary.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(AppColors.orangeSecondary)
                }

                Toggle("Open Now", isOn: $model.openNowOnly)
                    .tint(AppColors.orangePrimary)
                    .foregroundStyle(AppColors.textPrimary)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Radius")
                            .foregroundStyle(AppColors.textPrimary)
                        Spacer()
                        Text(String(format: "%.1f mi", model.radiusMiles))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    Slider(value: $model.radiusMiles, in: 0.5...10.0, step: 0.5)
                        .tint(AppColors.orangePrimary)
                }
            }
            .padding(16)
            .cinematicCard(cornerRadius: 22)
        }
        .frame(maxWidth: 520)
    }
}

private struct RefineSheetView: View {
    @FocusState var locationFieldFocused: Bool
    @State private var showLocationHint: Bool = false
    let onSearch: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                MagazineControls(locationFieldFocused: _locationFieldFocused, showLocationHint: $showLocationHint)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
        .background(CinematicBackdrop().ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            Button {
                onSearch()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.clockwise")
                        .font(AppFonts.display(15, weight: .bold))
                    Text("Update Picks")
                        .font(AppFonts.display(16, weight: .heavy))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .padding(.horizontal, 20)
            }
            .buttonStyle(PrimaryCinematicButtonStyle())
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 12)
            .background(AppColors.background)
        }
    }
}

private struct MagazineSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(AppFonts.display(12, weight: .heavy))
            .tracking(2)
            .foregroundStyle(AppColors.orangeSecondary)
            .padding(.horizontal, 4)
    }
}

private struct QuizPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFonts.body(14, weight: .bold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .foregroundStyle(isSelected ? Color.black : AppColors.textPrimary)
                .background(
                    RoundedRectangle(cornerRadius: 999)
                        .fill(isSelected ? AppColors.orangeSecondary : Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 999)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

private struct QuizTile: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(AppFonts.display(15, weight: .heavy))
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(AppFonts.display(16, weight: .bold))
            }
            .foregroundStyle(isSelected ? Color.black : AppColors.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? AppColors.orangeSecondary : Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ResultsHero: View {
    let location: String
    let count: Int
    let onRefine: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Tonight’s Picks")
                    .font(AppFonts.display(20, weight: .heavy))
                    .foregroundStyle(AppColors.textPrimary)

                Text(location.isEmpty ? "Nearby" : location)
                    .font(AppFonts.body(14, weight: .semibold))
                    .foregroundStyle(AppColors.textSecondary)

                Text("\(count) places to try")
                    .font(AppFonts.display(12, weight: .heavy))
                    .foregroundStyle(AppColors.orangeSecondary)
            }

            Spacer()

            Button(action: onRefine) {
                Label("Refine", systemImage: "slider.horizontal.3")
                    .font(AppFonts.display(13, weight: .heavy))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .cinematicCard(cornerRadius: 22)
    }
}

private struct LoadingHero: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("Generating Picks…")
                    .font(AppFonts.display(20, weight: .heavy))
                    .foregroundStyle(AppColors.textPrimary)

                HStack(spacing: 10) {
                    ProgressView()
                        .tint(AppColors.orangePrimary)
                    Text("Calling Google Places…")
                        .font(AppFonts.body(14, weight: .semibold))
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            Spacer()
        }
        .padding(16)
        .cinematicCard(cornerRadius: 22)
    }
}

#Preview("Search – Default") {
    SearchView(onNavigateToDetail: { _ in }, onShowFavorites: {})
        .environmentObject(RestaurantSearchViewModel(service: RestaurantService(apiKey: GOOGLE_PLACES_API_KEY)))
}

#Preview("Search – iPhone SE") {
    SearchView(onNavigateToDetail: { _ in }, onShowFavorites: {})
        .environmentObject(RestaurantSearchViewModel(service: RestaurantService(apiKey: GOOGLE_PLACES_API_KEY)))
        .previewDevice("iPhone SE (3rd generation)")
}

#Preview("Search – iPhone 15 Pro Max") {
    SearchView(onNavigateToDetail: { _ in }, onShowFavorites: {})
        .environmentObject(RestaurantSearchViewModel(service: RestaurantService(apiKey: GOOGLE_PLACES_API_KEY)))
        .previewDevice("iPhone 15 Pro Max")
}
