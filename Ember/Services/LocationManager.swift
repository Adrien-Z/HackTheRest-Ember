//
//  LocationManager.swift
//  Ember
//
//  Created by Ivy on 2026/7/25.
//

import CoreLocation
import Foundation

enum LocationManagerError: LocalizedError {
    case authorizationDenied
    case locationUnavailable

    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "Location permission is denied."
        case .locationUnavailable:
            return "Unable to determine current location."
        }
    }
}

@MainActor
final class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()

    private let manager = CLLocationManager()
    private var locationContinuations: [UUID: CheckedContinuation<CLLocation, Error>] = [:]
    private var isRequestInFlight = false

    @Published var location: CLLocation?

    private override init() {
        super.init()

        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestLocation() {
        guard !isRequestInFlight else {
            return
        }

        isRequestInFlight = true
        print("📍 location request started")
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    func currentLocation() async throws -> CLLocation {
        if let location {
            return location
        }

        let continuationID = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                locationContinuations[continuationID] = continuation
                requestLocation()
            }
        } onCancel: {
            Task { @MainActor in
                self.cancelLocationContinuation(id: continuationID)
            }
        }
    }

    private func resumeLocationContinuations(with result: Result<CLLocation, Error>) {
        let continuations = locationContinuations
        locationContinuations.removeAll()
        isRequestInFlight = false

        for continuation in continuations.values {
            switch result {
            case .success(let location):
                continuation.resume(returning: location)
            case .failure(let error):
                continuation.resume(throwing: error)
            }
        }
    }

    private func cancelLocationContinuation(id: UUID) {
        guard let continuation = locationContinuations.removeValue(forKey: id) else {
            return
        }

        continuation.resume(throwing: CancellationError())
    }
}

extension LocationManager: @preconcurrency CLLocationManagerDelegate {
    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let latestLocation = locations.first else {
            resumeLocationContinuations(with: .failure(LocationManagerError.locationUnavailable))
            return
        }

        location = latestLocation
        print("📍 location received")
        print("Latitude:", latestLocation.coordinate.latitude)
        print("Longitude:", latestLocation.coordinate.longitude)

        resumeLocationContinuations(with: .success(latestLocation))
    }

    func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        print(error.localizedDescription)
        resumeLocationContinuations(with: .failure(error))
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .denied, .restricted:
            resumeLocationContinuations(with: .failure(LocationManagerError.authorizationDenied))
        default:
            break
        }
    }
}
