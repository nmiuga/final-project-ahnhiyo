import Foundation

let GOOGLE_PLACES_API_KEY = "AIzaSyB-Q8DbTyI5IBSYgy0Dqcb5TNYJQwPgJQo"

enum AppStrings {
    static let appTitle = "What Are We Eating?"
}

func googlePlacesPhotoURL(photoReference: String, maxWidth: Int = 800) -> URL? {
    var components = URLComponents(string: "https://maps.googleapis.com/maps/api/place/photo")
    components?.queryItems = [
        URLQueryItem(name: "maxwidth", value: String(maxWidth)),
        URLQueryItem(name: "photo_reference", value: photoReference),
        URLQueryItem(name: "key", value: GOOGLE_PLACES_API_KEY)
    ]
    return components?.url
}
