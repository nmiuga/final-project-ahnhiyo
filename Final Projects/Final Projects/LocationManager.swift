import CoreLocation
import Foundation
import Combine

@MainActor
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    enum LocationError: LocalizedError {
        case denied
        case restricted
        case unavailable

        var errorDescription: String? {
            switch self {
            case .denied:
                return "Location access is denied. Enable it in Settings to get nearby restaurants automatically."
            case .restricted:
                return "Location access is restricted on this device."
            case .unavailable:
                return "Couldn’t determine your location."
            }
        }
    }

    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var coordinate: CLLocationCoordinate2D?
    @Published private(set) var errorMessage: String?

    private let manager: CLLocationManager
    private var requestContinuation: CheckedContinuation<CLLocationCoordinate2D, Error>?

    override init() {
        let manager = CLLocationManager()
        self.manager = manager
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    private var hasWhenInUseUsageDescription: Bool {
        Bundle.main.object(forInfoDictionaryKey: "NSLocationWhenInUseUsageDescription") != nil
    }

    func requestPermissionIfNeeded() {
        authorizationStatus = manager.authorizationStatus

        guard hasWhenInUseUsageDescription else {
            errorMessage = "Missing Location usage description. In Xcode, go to Target → Info and add “Privacy - Location When In Use Usage Description”."
            return
        }

        switch authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .restricted:
            errorMessage = LocationError.restricted.localizedDescription
        case .denied:
            errorMessage = LocationError.denied.localizedDescription
        default:
            break
        }
    }

    func requestOneShotLocation() async throws -> CLLocationCoordinate2D {
        authorizationStatus = manager.authorizationStatus

        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            break
        case .notDetermined:
            requestPermissionIfNeeded()
            throw LocationError.unavailable
        case .restricted:
            throw LocationError.restricted
        case .denied:
            throw LocationError.denied
        @unknown default:
            throw LocationError.unavailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.requestContinuation?.resume(throwing: LocationError.unavailable)
            self.requestContinuation = continuation
            self.errorMessage = nil
            self.manager.requestLocation()
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            errorMessage = nil
        case .restricted:
            errorMessage = LocationError.restricted.localizedDescription
        case .denied:
            errorMessage = LocationError.denied.localizedDescription
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else {
            requestContinuation?.resume(throwing: LocationError.unavailable)
            requestContinuation = nil
            return
        }

        let coordinate = location.coordinate
        self.coordinate = coordinate
        requestContinuation?.resume(returning: coordinate)
        requestContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        requestContinuation?.resume(throwing: error)
        requestContinuation = nil
    }
}
