import Flutter
import UIKit
import CoreMotion
import Firebase
import AppTrackingTransparency
import WatchConnectivity

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
  private var watchChannel: FlutterMethodChannel?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Initialize Firebase if configuration exists
    if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
       FileManager.default.fileExists(atPath: path) {
        FirebaseApp.configure()
    } else {
        print("⚠️ GoogleService-Info.plist not found - Firebase analytics disabled")
    }
    
    GeneratedPluginRegistrant.register(with: self)

    // Register native plugins
    if let registrar = self.registrar(forPlugin: "AltitudePlugin") {
        AltitudePlugin.register(with: registrar)
    }
    if let registrar = self.registrar(forPlugin: "BarometerPlugin") {
        BarometerPlugin.register(with: registrar)
    }
    
    // Setup Watch Connectivity
    if let controller = window?.rootViewController as? FlutterViewController {
        setupWatchConnectivity(with: controller.binaryMessenger)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func setupWatchConnectivity(with messenger: FlutterBinaryMessenger) {
    watchChannel = FlutterMethodChannel(
      name: "com.captainvfr.watch_connectivity",
      binaryMessenger: messenger
    )
    
    // Setup WatchConnectivity session if supported
    if WCSession.isSupported() {
      let session = WCSession.default
      session.delegate = self
      session.activate()
    }
    
    // Handle Flutter method calls
    watchChannel?.setMethodCallHandler { [weak self] call, result in
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
    
    let message: [String: Any] = ["action": "syncState", "isTracking": isTracking]
    
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

// MARK: - WCSessionDelegate
extension AppDelegate: WCSessionDelegate {
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
          self?.watchChannel?.invokeMethod("startTracking", arguments: nil)
        case "stopTracking":
          self?.watchChannel?.invokeMethod("stopTracking", arguments: nil)
        default:
          // Handle flight data from watch
          self?.watchChannel?.invokeMethod("flightDataUpdate", arguments: message)
        }
      }
    }
  }
}
