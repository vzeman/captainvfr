import Flutter
import UIKit
import CoreMotion

public class AltitudePlugin: NSObject, FlutterPlugin {
    private var altimeter: CMAltimeter?
    private var eventSink: FlutterEventSink?
    private var isTracking = false

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "altitude_service", binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: "altitude_stream", binaryMessenger: registrar.messenger())

        let instance = AltitudePlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isAltimeterAvailable":
            result(CMAltimeter.isRelativeAltitudeAvailable())
            
        case "startAltitudeUpdates":
            startAltitudeUpdates(result: result)

        case "stopAltitudeUpdates":
            stopAltitudeUpdates(result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func startAltitudeUpdates(result: @escaping FlutterResult) {
        guard CMAltimeter.isRelativeAltitudeAvailable() else {
            result(FlutterError(code: "UNAVAILABLE", message: "Altimeter not available", details: nil))
            return
        }

        if isTracking {
            result(nil)
            return
        }

        altimeter = CMAltimeter()
        isTracking = true

        altimeter?.startRelativeAltitudeUpdates(to: OperationQueue.main) { [weak self] (data, error) in
            guard let self = self else { return }

            if let error = error {
                self.eventSink?(FlutterError(code: "SENSOR_ERROR",
                                           message: "Altimeter error: \(error.localizedDescription)",
                                           details: nil))
                return
            }

            if let altitudeData = data {
                let altitudeMeters = altitudeData.relativeAltitude.doubleValue
                let pressureKPa = altitudeData.pressure.doubleValue
                let pressureHPa = pressureKPa * 10.0 // Convert kPa to hPa

                let result: [String: Any] = [
                    "altitude": altitudeMeters,
                    "pressure": pressureHPa,
                    "timestamp": Date().timeIntervalSince1970 * 1000 // milliseconds
                ]

                self.eventSink?(result)
            }
        }

        result(nil)
    }
    
    private func stopAltitudeUpdates(result: @escaping FlutterResult) {
        altimeter?.stopRelativeAltitudeUpdates()
        altimeter = nil
        isTracking = false
        result(nil)
    }
}

// MARK: - FlutterStreamHandler
extension AltitudePlugin: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}
