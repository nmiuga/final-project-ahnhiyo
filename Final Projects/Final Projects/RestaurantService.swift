import Foundation
import CoreLocation

actor RestaurantService {
    enum ServiceError: LocalizedError {
        case missingAPIKey
        case invalidURL
        case badResponse
        case apiError(String)
        case geocodingFailed

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "Missing Google Places API key. Add it in Constants.swift."
            case .invalidURL:
                return "Could not build the request URL."
            case .badResponse:
                return "Unexpected server response. Please try again."
            case .apiError(let message):
                return message
            case .geocodingFailed:
                return "Couldn’t find that location. Try a city, neighborhood, or ZIP code."
            }
        }
    }

    private let apiKey: String
    private let session: URLSession

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    struct LocationPrediction: Identifiable, Hashable {
        let id: String
        let description: String
    }

    func geocodeLocation(_ location: String) async throws -> CLLocationCoordinate2D {
        let geocoder = CLGeocoder()
        let placemarks = try await geocoder.geocodeAddressString(location)
        guard let coordinate = placemarks.first?.location?.coordinate else {
            throw ServiceError.geocodingFailed
        }
        return coordinate
    }

    func searchRestaurants(near location: String) async throws -> (coordinate: CLLocationCoordinate2D, restaurants: [Restaurant]) {
        try await searchRestaurants(near: location, query: nil)
    }

    func searchRestaurants(near location: String, query: String?) async throws -> (coordinate: CLLocationCoordinate2D, restaurants: [Restaurant]) {
        try await searchRestaurants(near: location, coordinate: nil, radiusMiles: 10.0, keyword: nil, openNow: false, queryFallback: query)
    }

    func searchRestaurants(
        near location: String,
        coordinate: CLLocationCoordinate2D?,
        radiusMiles: Double,
        keyword: String?,
        openNow: Bool,
        queryFallback: String?
    ) async throws -> (coordinate: CLLocationCoordinate2D, restaurants: [Restaurant]) {
        let trimmed = location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ServiceError.geocodingFailed
        }
        guard apiKey != "YOUR_KEY_HERE" else {
            throw ServiceError.missingAPIKey
        }

        let resolvedCoordinate: CLLocationCoordinate2D
        if let coordinate {
            resolvedCoordinate = coordinate
        } else {
            resolvedCoordinate = try await geocodeLocation(trimmed)
        }

        let meters = max(500, min(Int(radiusMiles * 1609.344), 50_000))
        let placeIDs = try await nearbySearchPlaceIDs(
            coordinate: resolvedCoordinate,
            radiusMeters: meters,
            keyword: keyword,
            openNow: openNow
        )

        if placeIDs.isEmpty {
            let googleQuery = (queryFallback?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
                ?? "restaurants near \(trimmed)"
            let fallbackIDs = try await textSearchPlaceIDs(query: googleQuery)
            if fallbackIDs.isEmpty {
                return (resolvedCoordinate, [])
            }
            let fallbackRestaurants = try await fetchDetailsForPlaces(placeIDs: fallbackIDs, searchCoordinate: resolvedCoordinate)
            return (resolvedCoordinate, fallbackRestaurants)
        }

        let restaurants = try await fetchDetailsForPlaces(placeIDs: placeIDs, searchCoordinate: resolvedCoordinate)
        return (resolvedCoordinate, restaurants)
    }

    // MARK: - Private

    func autocompleteLocations(input: String) async throws -> [LocationPrediction] {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        guard apiKey != "YOUR_KEY_HERE" else { throw ServiceError.missingAPIKey }

        var components = URLComponents(string: "https://maps.googleapis.com/maps/api/place/autocomplete/json")
        components?.queryItems = [
            URLQueryItem(name: "input", value: trimmed),
            URLQueryItem(name: "types", value: "(regions)"),
            URLQueryItem(name: "key", value: apiKey)
        ]

        guard let url = components?.url else { throw ServiceError.invalidURL }
        let response: AutocompleteResponse = try await fetchJSON(url: url)

        switch response.status {
        case "OK":
            return response.predictions.map { LocationPrediction(id: $0.place_id, description: $0.description) }
        case "ZERO_RESULTS":
            return []
        default:
            throw ServiceError.apiError(response.error_message ?? "Google Places error: \(response.status)")
        }
    }

    func coordinateForPlaceID(_ placeID: String) async throws -> CLLocationCoordinate2D {
        guard apiKey != "YOUR_KEY_HERE" else { throw ServiceError.missingAPIKey }

        var components = URLComponents(string: "https://maps.googleapis.com/maps/api/place/details/json")
        components?.queryItems = [
            URLQueryItem(name: "place_id", value: placeID),
            URLQueryItem(name: "fields", value: "geometry"),
            URLQueryItem(name: "key", value: apiKey)
        ]

        guard let url = components?.url else { throw ServiceError.invalidURL }
        let response: PlaceDetailsResponse = try await fetchJSON(url: url)

        switch response.status {
        case "OK":
            guard let result = response.result, let geometry = result.geometry else { throw ServiceError.badResponse }
            return CLLocationCoordinate2D(latitude: geometry.location.lat, longitude: geometry.location.lng)
        default:
            throw ServiceError.apiError(response.error_message ?? "Google Places error: \(response.status)")
        }
    }

    private func nearbySearchPlaceIDs(
        coordinate: CLLocationCoordinate2D,
        radiusMeters: Int,
        keyword: String?,
        openNow: Bool
    ) async throws -> [String] {
        var components = URLComponents(string: "https://maps.googleapis.com/maps/api/place/nearbysearch/json")
        var items: [URLQueryItem] = [
            URLQueryItem(name: "location", value: "\(coordinate.latitude),\(coordinate.longitude)"),
            URLQueryItem(name: "radius", value: String(radiusMeters)),
            URLQueryItem(name: "type", value: "restaurant"),
            URLQueryItem(name: "key", value: apiKey)
        ]

        if openNow {
            items.append(URLQueryItem(name: "opennow", value: "true"))
        }

        let trimmedKeyword = keyword?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedKeyword, !trimmedKeyword.isEmpty {
            items.append(URLQueryItem(name: "keyword", value: trimmedKeyword))
        }

        components?.queryItems = items

        guard let url = components?.url else { throw ServiceError.invalidURL }
        let response: NearbySearchResponse = try await fetchJSON(url: url)

        switch response.status {
        case "OK":
            return Array(response.results.map { $0.place_id }.prefix(20))
        case "ZERO_RESULTS":
            return []
        default:
            throw ServiceError.apiError(response.error_message ?? "Google Places error: \(response.status)")
        }
    }

    private func textSearchPlaceIDs(query: String) async throws -> [String] {
        var components = URLComponents(string: "https://maps.googleapis.com/maps/api/place/textsearch/json")
        components?.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "type", value: "restaurant"),
            URLQueryItem(name: "key", value: apiKey)
        ]

        guard let url = components?.url else { throw ServiceError.invalidURL }
        let response: TextSearchResponse = try await fetchJSON(url: url)

        switch response.status {
        case "OK":
            return Array(response.results.map { $0.place_id }.prefix(20))
        case "ZERO_RESULTS":
            return []
        default:
            throw ServiceError.apiError(response.error_message ?? "Google Places error: \(response.status)")
        }
    }

    private func fetchDetailsForPlaces(placeIDs: [String], searchCoordinate: CLLocationCoordinate2D) async throws -> [Restaurant] {
        var restaurants: [Restaurant] = []
        restaurants.reserveCapacity(placeIDs.count)

        try await withThrowingTaskGroup(of: Restaurant?.self) { group in
            for placeID in placeIDs {
                group.addTask {
                    try await self.fetchRestaurantDetails(placeID: placeID, searchCoordinate: searchCoordinate)
                }
            }

            for try await restaurant in group {
                if let restaurant {
                    restaurants.append(restaurant)
                }
            }
        }

        return restaurants
    }

    private func fetchRestaurantDetails(placeID: String, searchCoordinate: CLLocationCoordinate2D) async throws -> Restaurant? {
        var components = URLComponents(string: "https://maps.googleapis.com/maps/api/place/details/json")
        components?.queryItems = [
            URLQueryItem(name: "place_id", value: placeID),
            URLQueryItem(name: "fields", value: "name,formatted_address,rating,price_level,opening_hours,photos,formatted_phone_number,website,types,geometry"),
            URLQueryItem(name: "key", value: apiKey)
        ]

        guard let url = components?.url else { throw ServiceError.invalidURL }
        let response: PlaceDetailsResponse = try await fetchJSON(url: url)

        switch response.status {
        case "OK":
            guard let result = response.result else { return nil }
            let cuisine = cuisineLabel(from: result.types)
            let bestPhoto = selectBestPhoto(from: result.photos)
            let photoRef = bestPhoto?.photo_reference

            let isOpen = result.opening_hours?.open_now ?? false
            let weekdayText = result.opening_hours?.weekday_text ?? []
            let rating = result.rating ?? 0.0
            let priceLevel = result.price_level ?? 0

            let latitude = result.geometry?.location.lat ?? 0
            let longitude = result.geometry?.location.lng ?? 0
            let distanceMiles = computeDistanceMiles(from: searchCoordinate, to: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))

            return Restaurant(
                id: placeID,
                name: result.name ?? "Unknown",
                address: result.formatted_address ?? "",
                rating: rating,
                priceLevel: priceLevel,
                isOpenNow: isOpen,
                cuisine: cuisine,
                photoReference: photoRef,
                photoWidth: bestPhoto?.width,
                photoHeight: bestPhoto?.height,
                phoneNumber: result.formatted_phone_number,
                website: result.website,
                weekdayHours: weekdayText,
                latitude: latitude,
                longitude: longitude,
                distanceMiles: distanceMiles,
                isFavorited: false
            )
        case "NOT_FOUND":
            return nil
        default:
            throw ServiceError.apiError(response.error_message ?? "Google Places error: \(response.status)")
        }
    }

    private func computeDistanceMiles(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double? {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        let meters = fromLocation.distance(from: toLocation)
        guard meters.isFinite else { return nil }
        return meters / 1609.344
    }

    private func cuisineLabel(from types: [String]?) -> String {
        let types = types ?? []

        let known: [(key: String, label: String)] = [
            ("mexican", "Mexican"),
            ("italian", "Italian"),
            ("chinese", "Chinese"),
            ("japanese", "Japanese"),
            ("american", "American"),
            ("indian", "Indian"),
            ("thai", "Thai"),
            ("mediterranean", "Mediterranean"),
            ("fast_food", "Fast Food")
        ]

        for type in types {
            for entry in known where type.contains(entry.key) {
                return entry.label
            }
        }

        if let first = types.first {
            return first
                .replacingOccurrences(of: "_", with: " ")
                .split(separator: " ")
                .map { $0.capitalized }
                .joined(separator: " ")
        }

        return "Restaurant"
    }

    private func selectBestPhoto(from photos: [Photo]?) -> Photo? {
        guard let photos, !photos.isEmpty else { return nil }

        let minAspect: Double = 0.65
        let maxAspect: Double = 2.20
        let preferredAspect: Double = 1.45

        let candidates: [(photo: Photo, score: Double)] = photos.compactMap { photo in
            guard let ref = photo.photo_reference, !ref.isEmpty else { return nil }
            guard let w = photo.width, let h = photo.height, w > 0, h > 0 else {
                return (photo, 10_000)
            }
            let aspect = Double(w) / Double(h)
            guard aspect >= minAspect, aspect <= maxAspect else { return nil }
            return (photo, abs(aspect - preferredAspect))
        }

        return candidates.min(by: { $0.score < $1.score })?.photo
    }

    private func fetchJSON<T: Decodable>(url: URL) async throws -> T {
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw ServiceError.badResponse
        }

        if !(200...299).contains(http.statusCode) {
            if let message = parseGoogleErrorMessage(from: data) {
                throw ServiceError.apiError("Google API error (\(http.statusCode)): \(message)")
            }
            throw ServiceError.apiError("Google API error (\(http.statusCode)). Check API key restrictions, enabled APIs, and billing.")
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            if let message = parseGoogleErrorMessage(from: data) {
                throw ServiceError.apiError(message)
            }
            throw ServiceError.badResponse
        }
    }

    private func parseGoogleErrorMessage(from data: Data) -> String? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        if let errorMessage = object["error_message"] as? String {
            return errorMessage
        }

        if
            let error = object["error"] as? [String: Any],
            let message = error["message"] as? String
        {
            return message
        }

        if let status = object["status"] as? String, status != "OK" {
            return "Google Places status: \(status)"
        }

        return nil
    }

    // MARK: - DTOs

    private struct TextSearchResponse: Decodable {
        let status: String
        let error_message: String?
        let results: [TextSearchResult]
    }

    private struct TextSearchResult: Decodable {
        let place_id: String
    }

    private struct PlaceDetailsResponse: Decodable {
        let status: String
        let error_message: String?
        let result: PlaceDetailsResult?
    }

    private struct PlaceDetailsResult: Decodable {
        let name: String?
        let formatted_address: String?
        let rating: Double?
        let price_level: Int?
        let opening_hours: OpeningHours?
        let photos: [Photo]?
        let formatted_phone_number: String?
        let website: String?
        let types: [String]?
        let geometry: Geometry?
    }

    private struct OpeningHours: Decodable {
        let open_now: Bool?
        let weekday_text: [String]?
    }

    private struct Photo: Decodable {
        let photo_reference: String?
        let width: Int?
        let height: Int?
    }

    private struct Geometry: Decodable {
        let location: Location
    }

    private struct Location: Decodable {
        let lat: Double
        let lng: Double
    }

    private struct AutocompleteResponse: Decodable {
        let status: String
        let error_message: String?
        let predictions: [AutocompletePrediction]
    }

    private struct AutocompletePrediction: Decodable {
        let description: String
        let place_id: String
    }

    private struct NearbySearchResponse: Decodable {
        let status: String
        let error_message: String?
        let results: [NearbySearchResult]
    }

    private struct NearbySearchResult: Decodable {
        let place_id: String
    }
}
