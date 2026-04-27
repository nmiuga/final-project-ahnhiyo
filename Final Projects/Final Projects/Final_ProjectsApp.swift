//
//  Final_ProjectsApp.swift
//  Final Projects
//
//  Created by xuan nhi on 4/22/26.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

@main
struct Final_ProjectsApp: App {
    @StateObject private var favorites = FavoritesManager()
    @StateObject private var searchModel = RestaurantSearchViewModel(service: RestaurantService(apiKey: GOOGLE_PLACES_API_KEY))
    @State private var showSplash: Bool = true

    init() {
        AppFontRegistrar.registerFonts()
        configureGlobalTypography()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(favorites)
                    .environmentObject(searchModel)

                if showSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(10)
                }
            }
            .task {
                guard showSplash else { return }
                try? await Task.sleep(nanoseconds: 1_050_000_000)
                withAnimation(.easeOut(duration: 0.35)) {
                    showSplash = false
                }
            }
        }
    }

    private func configureGlobalTypography() {
#if os(iOS)
        let bodyFont = UIFont(name: "Alata-Regular", size: 11) ?? UIFont.systemFont(ofSize: 11, weight: .semibold)
        let displayFont = UIFont(name: "CalSans-Regular", size: 17) ?? UIFont.systemFont(ofSize: 17, weight: .heavy)
        let displayFontLarge = UIFont(name: "CalSans-Regular", size: 34) ?? UIFont.systemFont(ofSize: 34, weight: .heavy)

        UINavigationBar.appearance().titleTextAttributes = [
            .font: displayFont,
            .foregroundColor: UIColor.white
        ]
        UINavigationBar.appearance().largeTitleTextAttributes = [
            .font: displayFontLarge,
            .foregroundColor: UIColor.white
        ]

        UITabBarItem.appearance().setTitleTextAttributes([.font: bodyFont], for: .normal)
        UITabBarItem.appearance().setTitleTextAttributes([.font: bodyFont], for: .selected)

        UISegmentedControl.appearance().setTitleTextAttributes([.font: bodyFont], for: .normal)
        UISegmentedControl.appearance().setTitleTextAttributes([.font: bodyFont], for: .selected)
#endif
    }
}
