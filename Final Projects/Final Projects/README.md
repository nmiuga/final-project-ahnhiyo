# What Are We Eating?

A SwiftUI iOS app for discovering nearby restaurants. You search a location, browse results, swipe through picks, and save the ones you like. It's powered by the Google Places API and built as a final project for my native app development class.

---

## Screenshots

<!-- Will add screenshots after image sizing is dealt with. :( -->

---

## Features

- Search restaurants by city, neighborhood, or ZIP code
- Filter by cuisine type, price range, distance, and open now
- Swipe through restaurants one at a time (swipe right to save, left to skip)
- Browse all results in a scrollable list with sorting options
- View full details — hours, phone, website, directions
- Save favorites that persist between sessions
- "Surprise Me" tab that randomly picks a restaurant from your last search

---

## How it's built

The app uses SwiftUI for all the UI and `async/await` for networking. Google Places handles the restaurant data — it does a nearby search to get place IDs, then fetches full details for each one concurrently. Favorites are stored locally with `UserDefaults` using `JSONEncoder/JSONDecoder`.

**Main files:**

```
RestaurantService.swift    — all Google Places API calls
Restaurant.swift           — data model
LocationManager.swift      — CoreLocation wrapper
FavoritesManager.swift     — favorites persistence (ObservableObject)
ContentView.swift          — root navigation + tab bar
SearchView.swift           — search input and filters
SwipeView.swift            — card swipe interface
ResultsView.swift          — scrollable list view
DetailView.swift           — single restaurant detail page
FavoritesView.swift        — saved restaurants
SurpriseView.swift         — random pick tab
RestaurantImage.swift      — async image loading with NSCache
Theme.swift                — colors, styles, reusable modifiers
Constants.swift            — API key
```

---

## Setup

1. Clone the repo and open in Xcode (15+)
2. Get a [Google Places API key](https://developers.google.com/maps/documentation/places/web-service/get-api-key) with **Places API** and **Geocoding API** enabled
3. Add your key to `Constants.swift`:
   ```swift
   let GOOGLE_PLACES_API_KEY = "YOUR_KEY_HERE"
   ```
4. Add a location permission string to `Info.plist`:
   - Key: `Privacy - Location When In Use Usage Description`
   - Value: e.g. `"Used to find restaurants near you"`
5. Build and run on iOS 17+

> Note: Google Places API has usage costs. Check your [Cloud Console](https://console.cloud.google.com/) to monitor usage.

---

## Requirements

- Xcode 15+
- iOS 17+
- Google Places API key

---

## Contact

Nhi Nguyen-Le
ahnhiyo@gmail.com

---

