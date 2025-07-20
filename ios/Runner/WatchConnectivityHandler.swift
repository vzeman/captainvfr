import Foundation
import WatchConnectivity
import Flutter

class WatchConnectivityHandler: NSObject {
    static let shared = WatchConnectivityHandler()
    private var flutterChannel: FlutterMethodChannel?
    
    private override init() {
        super.init()
    }
    
    func setup(with messenger: FlutterBinaryMessenger) {
        flutterChannel = FlutterMethodChannel(
            name: "com.captainvfr.watch_connectivity",
            binaryMessenger: messenger
        )
        
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
        
        // Handle Flutter method calls
        flutterChannel?.setMethodCallHandler { [weak self] call, result in
            switch call.method {
            case "sendTrackingState":
                if let args = call.arguments as? [String: Any],
                   let isTracking = args["isTracking"] as? Bool {
                    self?.sendTrackingStateToWatch(isTracking: isTracking)
                    result(nil)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                }
            case "sendFlightData":
                if let args = call.arguments as? [String: Any] {
                    self?.sendFlightDataToWatch(data: args)
                    result(nil)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    private func sendTrackingStateToWatch(isTracking: Bool) {
        guard WCSession.default.isPaired && WCSession.default.isWatchAppInstalled else { return }
        
        let message = ["action": "syncState", "isTracking": isTracking]
        
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: nil)
        } else {
            // Update application context for when watch becomes reachable
            try? WCSession.default.updateApplicationContext(message)
        }
    }
    
    private func sendFlightDataToWatch(data: [String: Any]) {
        guard WCSession.default.isPaired && WCSession.default.isWatchAppInstalled else { return }
        
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(data, replyHandler: nil, errorHandler: nil)
        }
    }
}

extension WatchConnectivityHandler: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("WCSession activation completed with state: \(activationState)")
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {}
    
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async { [weak self] in
            if let action = message["action"] as? String {
                switch action {
                case "startTracking":
                    self?.flutterChannel?.invokeMethod("startTracking", arguments: nil)
                case "stopTracking":
                    self?.flutterChannel?.invokeMethod("stopTracking", arguments: nil)
                default:
                    // Handle flight data from watch
                    self?.flutterChannel?.invokeMethod("flightDataUpdate", arguments: message)
                }
            }
        }
    }
}