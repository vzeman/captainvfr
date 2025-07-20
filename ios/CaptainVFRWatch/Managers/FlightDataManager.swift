import Foundation
import CoreLocation
import CoreMotion
import Combine

class FlightDataManager: NSObject, ObservableObject {
    static let shared = FlightDataManager()
    
    @Published var isTracking = false
    @Published var altitude: Double = 0.0
    @Published var groundSpeed: Double = 0.0
    @Published var heading: Double = 0.0
    @Published var track: Double = 0.0
    @Published var verticalSpeed: Double = 0.0
    @Published var pressure: Double = 29.92 // inHg
    
    private let locationManager = CLLocationManager()
    private let altimeter = CMAltimeter()
    private let motionManager = CMMotionManager()
    
    private var previousAltitude: Double?
    private var previousAltitudeTime: Date?
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        setupLocationManager()
        setupAltimeter()
        setupMotionManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
    }
    
    private func setupAltimeter() {
        if CMAltimeter.isRelativeAltitudeAvailable() {
            startAltimeterUpdates()
        }
    }
    
    private func setupMotionManager() {
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 1.0
        }
    }
    
    func startTracking() {
        isTracking = true
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
        startAltimeterUpdates()
        startMotionUpdates()
    }
    
    func stopTracking() {
        isTracking = false
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
        altimeter.stopRelativeAltitudeUpdates()
        motionManager.stopDeviceMotionUpdates()
    }
    
    private func startAltimeterUpdates() {
        altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, error in
            guard let self = self, let data = data, error == nil else { return }
            
            // Convert pressure from kPa to inHg (1 kPa = 0.2953 inHg)
            self.pressure = data.pressure.doubleValue * 0.2953
            
            // Calculate altitude from pressure (approximate)
            // Standard pressure at sea level is 29.92 inHg
            let pressureDifference = 29.92 - self.pressure
            let altitudeFromPressure = pressureDifference * 1000 // Rough approximation: 1 inHg = 1000 ft
            
            // Use GPS altitude if available, otherwise use pressure altitude
            if self.altitude == 0 {
                self.altitude = altitudeFromPressure
            }
            
            // Calculate vertical speed
            let currentTime = Date()
            if let prevAlt = self.previousAltitude, let prevTime = self.previousAltitudeTime {
                let timeDiff = currentTime.timeIntervalSince(prevTime)
                if timeDiff > 0 {
                    let altDiff = self.altitude - prevAlt
                    self.verticalSpeed = (altDiff / timeDiff) * 60 // Convert to feet per minute
                }
            }
            self.previousAltitude = self.altitude
            self.previousAltitudeTime = currentTime
        }
    }
    
    private func startMotionUpdates() {
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let motion = motion, error == nil else { return }
            
            // Use magnetometer data for more accurate heading if available
            if let heading = motion.heading {
                self?.heading = heading
            }
        }
    }
}

extension FlightDataManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Update altitude from GPS
        altitude = location.altitude * 3.28084 // Convert meters to feet
        
        // Update ground speed (convert m/s to knots)
        if location.speed >= 0 {
            groundSpeed = location.speed * 1.94384
        }
        
        // Update track
        if location.course >= 0 {
            track = location.course
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        if newHeading.headingAccuracy >= 0 {
            heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        }
    }
}