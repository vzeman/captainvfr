import SwiftUI

@main
struct CaptainVFRWatchApp: App {
    @WKApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, WKApplicationDelegate {
    func applicationDidFinishLaunching() {
        // Setup watch connectivity
        WatchConnectivityManager.shared.setupWatchConnectivity()
    }
}