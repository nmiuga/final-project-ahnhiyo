import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject private var model: RestaurantSearchViewModel

    let onNavigateToDetail: (Restaurant) -> Void
    let onShowFavorites: () -> Void

    @FocusState private var locationFieldFocused: Bool
    @State private var coverIndex: Int = Int.random(in: 0..<999)
    @State private var showLocationHint: Bool = false
    @State private var showRefineSheet: Bool = false

    private var cover: (kicker: String, headline: String, deck: String) {
        let options: [(String, String, String)] = [
            ("DISCOVER", "Your vibe. Your neighborhood.", "Answer a few quick questions — we’ll pull the shortlist."),
            ("TONIGHT", "Dinner without the decision fatigue.", "Pick a flavor, set the rules, and hit generate."),
            ("THE LIST", "Places worth leaving the house for.", "Filters first. Scrolling later."),
            ("EDITOR’S NOTE", "Find something that feels right.", "Cuisine, mood, price — then we go hunting.")
        ]
        return options[coverIndex % options.count]
    }

    var body: some View {
        ZStack {
            CinematicBackdrop().ignoresSafeArea()

            GeometryReader { _ in
                VStack(spacing: 0) {
                    if shouldShowResults {
                        resultsScreen
                    } else {
                        questionnaireScreen
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            coverIndex = Int.random(in: 0..<999)
        }
        .sheet(isPresented: $showRefineSheet) {
            NavigationStack {
                refineSheet
                    .navigationTitle("Refine")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showRefineSheet = false }
                                .font(AppFonts.display(15, weight: .bold))
                        }
                    }
            }
            .preferredColorScheme(.dark)
        }
    }

    private var shouldShowResults: Bool {
        model.hasSearched && !model.isLoading && (!model.filteredRestaurants.isEmpty || model.errorMessage != nil)
    }

    private var questionnaireScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                progressStrip
                whereCard
                partyCard
                flavorCard
                moodCard
                rulesCard
                ctaRow
                resultsSummary
            }
            .frame(maxWidth: 560, alignment: .center)
            .padding(.horizontal, 20)
            .safeAreaPadding(.top, 16)
            .safeAreaPadding(.bottom, 18)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    private var resultsScreen: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                header
                resultsHeaderBar
            }
            .frame(maxWidth: 560, alignment: .center)
            .padding(.horizontal, 20)
            .safeAreaPadding(.top, 16)
            .padding(.bottom, 12)

            Divider()
                .overlay(AppColors.cardBorder)

            Group {
                if model.isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(AppColors.orangePrimary)
                        Text("Finding restaurants…")
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = model.errorMessage, model.filteredRestaurants.isEmpty {
                    VStack(spacing: 10) {
                        Text("Couldn’t load restaurants")
                            .font(AppFonts.display(18, weight: .heavy))
                            .foregroundStyle(AppColors.textPrimary)
                        Text(error)
                            .font(AppFonts.body(13, weight: .semibold))
                            .foregroundStyle(AppColors.closedRed.opacity(0.95))
                            .multilineTextAlignment(.center)
                        Button("Try again") { Task { await model.search() } }
                            .font(AppFonts.display(15, weight: .heavy))
                            .padding(.horizontal, 22)
                            .padding(.vertical, 12)
                            .buttonStyle(PrimaryCinematicButtonStyle())
                    }
                    .padding(16)
                    .frame(maxWidth: 520)
                    .cinematicCard(cornerRadius: 22)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    switch model.resultsMode {
                    case .swipe:
                        SwipeView(restaurants: model.filteredRestaurants, onShowFavorites: onShowFavorites)
                    case .list:
                        ResultsView(restaurants: model.filteredRestaurants, sortOption: $model.sortOption)
                    }
                }
            }
            .background(CinematicBackdrop().ignoresSafeArea())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resultsHeaderBar: some View {
        HStack(spacing: 12) {
            Picker("View", selection: $model.resultsMode) {
                Text("Swipe").tag(RestaurantSearchViewModel.ResultsMode.swipe)
                Text("List").tag(RestaurantSearchViewModel.ResultsMode.list)
            }
            .pickerStyle(.segmented)
            .tint(AppColors.orangePrimary)

            Button {
                showRefineSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14, weight: .bold))
                    Text("Refine")
                        .font(AppFonts.display(14, weight: .heavy))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .buttonStyle(GhostCinematicButtonStyle())
            .frame(width: 110)
        }
        .frame(maxWidth: 520)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(AppStrings.appTitle.uppercased())
                .font(AppFonts.display(12, weight: .heavy))
                .tracking(2)
                .foregroundStyle(AppColors.orangeSecondary)

            Text(cover.kicker)
                .font(AppFonts.display(12, weight: .heavy))
                .tracking(2)
                .foregroundStyle(AppColors.textSecondary)

            Text(cover.headline)
                .font(AppFonts.display(30, weight: .heavy))
                .foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(cover.deck)
                .font(AppFonts.body(13, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: 520, alignment: .leading)
    }

    private var progressStrip: some View {
        let steps = completionSteps
        return HStack(spacing: 8) {
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 999)
                    .fill(i < steps ? AppColors.orangePrimary : Color.white.opacity(0.08))
                    .frame(height: 6)
            }
        }
        .frame(maxWidth: 520)
        .padding(.bottom, 4)
        .accessibilityLabel("Progress")
    }

    private var completionSteps: Int {
        var score = 0
        if !model.locationQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { score += 1 }
        if model.partySegment != .two { score += 1 }
        if model.selectedCuisine != "All" { score += 1 }
        if model.selectedVibe != .any { score += 1 }
        if model.openNowOnly || model.selectedPrice != .any || model.radiusMiles != 10.0 { score += 1 }
        return min(5, max(0, score))
    }

    private var whereCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("WHERE")

            VStack(alignment: .leading, spacing: 8) {
                Text("Where are we eating?")
                    .font(AppFonts.display(18, weight: .heavy))
                    .foregroundStyle(AppColors.textPrimary)

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
                        .foregroundStyle(AppColors.closedRed.opacity(0.95))
                }
            }
        }
        .frame(maxWidth: 520, alignment: .leading)
        .padding(16)
        .cinematicCard(cornerRadius: 22)
    }

    private var partyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("WHO’S COMING")

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
        .frame(maxWidth: 520, alignment: .leading)
        .padding(16)
        .cinematicCard(cornerRadius: 22)
    }

    private var flavorCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("THE FLAVOR")

            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(model.cuisines, id: \.self) { cuisine in
                        ChoicePill(title: cuisine, isSelected: model.selectedCuisine == cuisine) {
                            model.selectedCuisine = cuisine
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: 520, alignment: .leading)
        .padding(16)
        .cinematicCard(cornerRadius: 22)
    }

    private var moodCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("THE MOOD")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(RestaurantSearchViewModel.Vibe.allCases) { vibe in
                    ChoiceTile(title: vibe.rawValue, isSelected: model.selectedVibe == vibe) {
                        model.selectedVibe = vibe
                    }
                }
            }
        }
        .frame(maxWidth: 520, alignment: .leading)
        .padding(16)
        .cinematicCard(cornerRadius: 22)
    }

    private var rulesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("THE RULES")

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
                    Text("Radius")
                        .foregroundStyle(AppColors.textPrimary)
                    Spacer()
                    Text(String(format: "%.1f mi", model.radiusMiles))
                        .foregroundStyle(AppColors.textSecondary)
                }
                Slider(value: $model.radiusMiles, in: 0.5...10.0, step: 0.5)
                    .tint(AppColors.orangePrimary)
            }

            HStack {
                Text("Sort")
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                Picker("Sort", selection: $model.sortOption) {
                    ForEach(RestaurantSearchViewModel.SortOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .tint(AppColors.orangeSecondary)
            }
        }
        .frame(maxWidth: 520, alignment: .leading)
        .padding(16)
        .cinematicCard(cornerRadius: 22)
    }

    private var ctaRow: some View {
        HStack(spacing: 12) {
            Button {
                let location = model.locationQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !location.isEmpty else {
                    showLocationHint = true
                    locationFieldFocused = true
                    return
                }
                Task { await model.search() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .bold))
                    Text("Find restaurants")
                        .font(AppFonts.display(16, weight: .heavy))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(PrimaryCinematicButtonStyle())

            Button {
                model.resultsMode = .swipe
                let location = model.locationQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !location.isEmpty else {
                    showLocationHint = true
                    locationFieldFocused = true
                    return
                }
                Task { await model.search() }
            } label: {
                Image(systemName: "dice.fill")
                    .font(AppFonts.display(16, weight: .heavy))
                    .frame(width: 54, height: 48)
            }
            .buttonStyle(GhostCinematicButtonStyle())
            .accessibilityLabel("Surprise me")
        }
        .frame(maxWidth: 520)
    }

    @ViewBuilder
    private var resultsSummary: some View {
        if model.isLoading {
            VStack(spacing: 12) {
                ProgressView()
                    .tint(AppColors.orangePrimary)
                Text("Finding restaurants…")
                    .foregroundStyle(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 20)
        } else if let error = model.errorMessage, model.restaurants.isEmpty, model.hasSearched {
            VStack(spacing: 10) {
                Text("Couldn’t load restaurants")
                    .font(AppFonts.display(18, weight: .heavy))
                    .foregroundStyle(AppColors.textPrimary)
                Text(error)
                    .font(AppFonts.body(13, weight: .semibold))
                    .foregroundStyle(AppColors.closedRed.opacity(0.95))
                    .multilineTextAlignment(.center)
                Button("Retry") { Task { await model.search() } }
                    .font(AppFonts.display(15, weight: .heavy))
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .buttonStyle(PrimaryCinematicButtonStyle())
            }
            .padding(16)
            .frame(maxWidth: 520)
            .cinematicCard(cornerRadius: 22)
            .padding(.top, 10)
        } else if model.hasSearched {
            HStack(spacing: 10) {
                Text(model.filteredRestaurants.isEmpty ? "No matches yet." : "\(model.filteredRestaurants.count) matches — open Swipe or List.")
                    .foregroundStyle(AppColors.textSecondary)
                    .font(AppFonts.body(13, weight: .semibold))
                Spacer()
                if !model.filteredRestaurants.isEmpty {
                    Button("View") { }
                        .hidden()
                }
            }
            .frame(maxWidth: 520)
            .padding(.top, 6)
        } else {
            EmptyView()
        }
    }

    private var refineSheet: some View {
        ZStack {
            CinematicBackdrop().ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    whereCard
                    partyCard
                    flavorCard
                    moodCard
                    rulesCard

                    Button {
                        Task {
                            await model.search()
                            showRefineSheet = false
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 15, weight: .bold))
                            Text("Update picks")
                                .font(AppFonts.display(16, weight: .heavy))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(PrimaryCinematicButtonStyle())
                }
                .frame(maxWidth: 560, alignment: .center)
                .padding(.horizontal, 20)
                .safeAreaPadding(.top, 16)
                .safeAreaPadding(.bottom, 18)
            }
            .scrollIndicators(.hidden)
        }
    }
}

private struct SectionTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(AppFonts.display(12, weight: .heavy))
            .tracking(2)
            .foregroundStyle(AppColors.orangeSecondary)
    }
}

private struct ChoicePill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFonts.display(13, weight: .heavy))
                .foregroundStyle(isSelected ? Color.black : AppColors.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(isSelected ? AppColors.orangeSecondary : Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 999))
                .overlay(
                    RoundedRectangle(cornerRadius: 999)
                        .stroke(isSelected ? Color.clear : AppColors.cardBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct ChoiceTile: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(AppFonts.display(14, weight: .heavy))
                    .foregroundStyle(isSelected ? Color.black : AppColors.textPrimary)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(isSelected ? Color.black.opacity(0.9) : AppColors.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(isSelected ? AppColors.orangeSecondary : Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.clear : AppColors.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        DiscoverView(onNavigateToDetail: { _ in }, onShowFavorites: {})
            .environmentObject(RestaurantSearchViewModel(service: RestaurantService(apiKey: GOOGLE_PLACES_API_KEY)))
    }
}
