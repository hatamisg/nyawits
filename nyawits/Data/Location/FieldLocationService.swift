import Combine
import CoreLocation
import Foundation

@MainActor
final class FieldLocationService: NSObject, ObservableObject {
    @Published private(set) var coordinate: CLLocationCoordinate2D?
    @Published private(set) var horizontalAccuracy: CLLocationAccuracy?
    @Published var isPermissionAlertPresented = false
    @Published var errorMessage = "Location access is needed to show your current position on the map."

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestLocation() {
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return }
        guard CLLocationManager.locationServicesEnabled() else {
            errorMessage = "Location Services are turned off on this device."
            isPermissionAlertPresented = true
            return
        }

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            errorMessage = "Allow location access in Settings to show your current position."
            isPermissionAlertPresented = true
        @unknown default:
            errorMessage = "Your current location isn’t available right now."
            isPermissionAlertPresented = true
        }
    }
}

extension FieldLocationService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            errorMessage = "Allow location access in Settings to show your current position."
            isPermissionAlertPresented = true
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latestLocation = locations.last else { return }
        coordinate = latestLocation.coordinate
        horizontalAccuracy = latestLocation.horizontalAccuracy >= 0 ? latestLocation.horizontalAccuracy : nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = "Your current location couldn’t be determined. Please try again."
        isPermissionAlertPresented = true
    }
}
