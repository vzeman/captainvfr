import Flutter
import UIKit
import CoreMotion

// AltitudePlugin implementation moved to this file to avoid module issues
class AltitudePlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    private let altimeter = CMAltimeter()
    private var isUpdating = false
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = AltitudePlugin()
        
        // Method channel for one-time calls
        let methodChannel = FlutterMethodChannel(
            name: "altitude_service",
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        
        // Event channel for continuous updates
        let eventChannel = FlutterEventChannel(
            name: "altitude_service/updates",
            binaryMessenger: registrar.messenger()
        )
        eventChannel.setStreamHandler(instance)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isAltimeterAvailable":
            result(CMAltimeter.isRelativeAltitudeAvailable())
            
        case "startAltitudeUpdates":
            if CMAltimeter.isRelativeAltitudeAvailable() {
                startAltimeterUpdates()
                result(nil)
            } else {
                result(FlutterError(
                    code: "UNAVAILABLE",
                    message: "Altimeter is not available on this device",
                    details: nil
                ))
            }
            
        case "stopAltitudeUpdates":
            stopAltimeterUpdates()
            result(nil)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Altimeter Updates
    
    private func startAltimeterUpdates() {
        guard !isUpdating else { return }
        
        if CMAltimeter.isRelativeAltitudeAvailable() {
            isUpdating = true
            let queue = OperationQueue()
            queue.qualityOfService = .utility
            
            altimeter.startRelativeAltitudeUpdates(to: queue) { [weak self] (data, error) in
                guard let self = self, let data = data, error == nil else {
                    self?.eventSink?(FlutterError(
                        code: "SENSOR_ERROR",
                        message: error?.localizedDescription ?? "Unknown error",
                        details: nil
                    ))
                    return
                }
                
                // Convert pressure from kPa to hPa (1 kPa = 10 hPa)
                let pressureHPa = data.pressure.doubleValue * 10.0
                self.eventSink?(pressureHPa)
            }
        }
    }
    
    private func stopAltimeterUpdates() {
        guard isUpdating else { return }
        altimeter.stopRelativeAltitudeUpdates()
        isUpdating = false
    }
    
    // MARK: - FlutterStreamHandler
    
    public func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        stopAltimeterUpdates()
        return nil
    }
    
    deinit {
        stopAltimeterUpdates()
    }
}

// BarometerPlugin implementation
class BarometerPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    private let altimeter = CMAltimeter()
    private var isUpdating = false

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = BarometerPlugin()

        // Method channel for one-time calls
        let methodChannel = FlutterMethodChannel(
            name: "barometer_service",
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: methodChannel)

        // Event channel for continuous updates
        let eventChannel = FlutterEventChannel(
            name: "barometer_service/updates",
            binaryMessenger: registrar.messenger()
        )
        eventChannel.setStreamHandler(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isBarometerAvailable":
            result(CMAltimeter.isRelativeAltitudeAvailable())

        case "startBarometerUpdates":
            if CMAltimeter.isRelativeAltitudeAvailable() {
                startBarometerUpdates()
                result(nil)
            } else {
                result(FlutterError(
                    code: "UNAVAILABLE",
                    message: "Barometer is not available on this device",
                    details: nil
                ))
            }

        case "stopBarometerUpdates":
            stopBarometerUpdates()
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Barometer Updates

    private func startBarometerUpdates() {
        guard !isUpdating else { return }

        if CMAltimeter.isRelativeAltitudeAvailable() {
            isUpdating = true
            let queue = OperationQueue()
            queue.qualityOfService = .utility

            altimeter.startRelativeAltitudeUpdates(to: queue) { [weak self] (data, error) in
                guard let self = self, let data = data, error == nil else {
                    self?.eventSink?(FlutterError(
                        code: "SENSOR_ERROR",
                        message: error?.localizedDescription ?? "Unknown error",
                        details: nil
                    ))
                    return
                }

                // Convert pressure from kPa to hPa (1 kPa = 10 hPa)
                let pressureHPa = data.pressure.doubleValue * 10.0
                self.eventSink?(pressureHPa)
            }
        }
    }

    private func stopBarometerUpdates() {
        guard isUpdating else { return }
        altimeter.stopRelativeAltitudeUpdates()
        isUpdating = false
    }

    // MARK: - FlutterStreamHandler

    public func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        stopBarometerUpdates()
        return nil
    }

    deinit {
        stopBarometerUpdates()
    }
}

import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Register native plugins
    if let registrar = self.registrar(forPlugin: "AltitudePlugin") {
        AltitudePlugin.register(with: registrar)
    }
    if let registrar = self.registrar(forPlugin: "BarometerPlugin") {
        BarometerPlugin.register(with: registrar)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
