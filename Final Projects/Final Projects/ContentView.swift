//
//  ContentView.swift
//  Final Projects
//
//  Created by xuan nhi on 4/10/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var favorites: FavoritesManager

    private enum AppTab: Hashable {
        case search
        case favorites
        case surprise
    }

    @State private var selectedTab: AppTab = .surprise
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                CinematicBackdrop().ignoresSafeArea()

                TabView(selection: $selectedTab) {
                    SurpriseView(onGoToSearch: { selectedTab = .search })
                        .tabItem {
                            Label("Surprise", systemImage: "dice")
                        }
                        .tag(AppTab.surprise)

                    SearchView(
                        onNavigateToDetail: { restaurant in
                            showDetail(restaurant, replaceStack: false)
                        },
                        onShowFavorites: {
                            selectedTab = .favorites
                        }
                    )
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    .tag(AppTab.search)

                    FavoritesView()
                        .tabItem {
                            Label("Favorites", systemImage: "heart")
                        }
                        .badge(favorites.favorites.count)
                        .tag(AppTab.favorites)
                }
            }
            .navigationDestination(for: Restaurant.self) { restaurant in
                DetailView(restaurant: restaurant)
            }
        }
        .preferredColorScheme(.dark)
        .font(AppFonts.body(15))
    }

    private func showDetail(_ restaurant: Restaurant, replaceStack: Bool) {
        if replaceStack {
            path = NavigationPath()
        }
        path.append(restaurant)
    }
}

#Preview {
    ContentView()
        .environmentObject(FavoritesManager())
        .environmentObject(RestaurantSearchViewModel(service: RestaurantService(apiKey: GOOGLE_PLACES_API_KEY)))
}
