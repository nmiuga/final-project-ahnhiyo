import Foundation

struct Restaurant: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let address: String
    let rating: Double
    let priceLevel: Int
    let isOpenNow: Bool
    let cuisine: String
    let photoReference: String?
    let photoWidth: Int?
    let photoHeight: Int?
    let phoneNumber: String?
    let website: String?
    let weekdayHours: [String]
    let latitude: Double
    let longitude: Double
    var distanceMiles: Double?
    var isFavorited: Bool = false

    init(
        id: String,
        name: String,
        address: String,
        rating: Double,
        priceLevel: Int,
        isOpenNow: Bool,
        cuisine: String,
        photoReference: String?,
        photoWidth: Int? = nil,
        photoHeight: Int? = nil,
        phoneNumber: String?,
        website: String?,
        weekdayHours: [String],
        latitude: Double,
        longitude: Double,
        distanceMiles: Double? = nil,
        isFavorited: Bool = false
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.rating = rating
        self.priceLevel = priceLevel
        self.isOpenNow = isOpenNow
        self.cuisine = cuisine
        self.photoReference = photoReference
        self.photoWidth = photoWidth
        self.photoHeight = photoHeight
        self.phoneNumber = phoneNumber
        self.website = website
        self.weekdayHours = weekdayHours
        self.latitude = latitude
        self.longitude = longitude
        self.distanceMiles = distanceMiles
        self.isFavorited = isFavorited
    }

    var priceSymbols: String {
        guard (1...4).contains(priceLevel) else { return "—" }
        return String(repeating: "$", count: priceLevel)
    }

    var distanceLabel: String? {
        guard let distanceMiles else { return nil }
        return String(format: "%.1f mi", distanceMiles)
    }

    var photoAspectRatio: Double? {
        guard let photoWidth, let photoHeight, photoWidth > 0, photoHeight > 0 else { return nil }
        return Double(photoWidth) / Double(photoHeight)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Restaurant, rhs: Restaurant) -> Bool {
        lhs.id == rhs.id
    }
}
