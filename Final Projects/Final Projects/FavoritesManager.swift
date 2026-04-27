import Foundation
import SwiftUI
import Combine

@MainActor
final class FavoritesManager: ObservableObject {
    @Published private(set) var favorites: [Restaurant] = []

    private let storageKey = "WhatAreWeEating.Favorites"

    init() {
        load()
    }

    func toggleFavorite(_ restaurant: Restaurant) {
        if let index = favorites.firstIndex(where: { $0.id == restaurant.id }) {
            favorites.remove(at: index)
        } else {
            favorites.insert(restaurant, at: 0)
        }
        persist()
    }

    func isFavorited(_ restaurant: Restaurant) -> Bool {
        favorites.contains(where: { $0.id == restaurant.id })
    }

    func remove(at offsets: IndexSet) {
        favorites.remove(atOffsets: offsets)
        persist()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            favorites = []
            return
        }

        do {
            favorites = try JSONDecoder().decode([Restaurant].self, from: data)
        } catch {
            favorites = []
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(favorites)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            // Intentionally ignore persistence failures.
        }
    }
}
