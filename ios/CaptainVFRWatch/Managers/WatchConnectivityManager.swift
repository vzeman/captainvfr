import Foundation
import WatchConnectivity

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    private override init() {
        super.init()
    }
    
    func setupWatchConnectivity() {
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    func sendStartTracking() {
        guard WCSession.default.isReachable else { return }
        
        let message = ["action": "startTracking"]
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("Error sending start tracking message: \(error)")
        }
    }
    
    func sendStopTracking() {
        guard WCSession.default.isReachable else { return }
        
        let message = ["action": "stopTracking"]
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("Error sending stop tracking message: \(error)")
        }
    }
    
    func sendFlightData() {
        guard WCSession.default.isReachable else { return }
        
        let flightData = FlightDataManager.shared
        let data: [String: Any] = [
            "altitude": flightData.altitude,
            "groundSpeed": flightData.groundSpeed,
            "heading": flightData.heading,
            "track": flightData.track,
            "verticalSpeed": flightData.verticalSpeed,
            "pressure": flightData.pressure,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        WCSession.default.sendMessage(data, replyHandler: nil) { error in
            print("Error sending flight data: \(error)")
        }
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession activation failed: \(error)")
        } else {
            print("WCSession activated with state: \(activationState)")
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            if let action = message["action"] as? String {
                switch action {
                case "startTracking":
                    FlightDataManager.shared.startTracking()
                case "stopTracking":
                    FlightDataManager.shared.stopTracking()
                case "syncState":
                    if let isTracking = message["isTracking"] as? Bool {
                        FlightDataManager.shared.isTracking = isTracking
                    }
                default:
                    break
                }
            }
        }
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}