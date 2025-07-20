import SwiftUI

struct ContentView: View {
    @StateObject private var flightDataManager = FlightDataManager.shared
    
    var body: some View {
        if flightDataManager.isTracking {
            TrackingView()
        } else {
            IdleView()
        }
    }
}