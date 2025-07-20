import SwiftUI

struct TrackingView: View {
    @StateObject private var flightDataManager = FlightDataManager.shared
    @State private var currentTime = Date()
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private var zuluTimeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        return formatter
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 15) {
                // Header with Zulu Time
                HStack {
                    VStack(alignment: .leading) {
                        Text("TRACKING")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.green)
                        Text(zuluTimeFormatter.string(from: currentTime))
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                    }
                    Spacer()
                    
                    // Stop Button
                    Button(action: {
                        flightDataManager.stopTracking()
                        WatchConnectivityManager.shared.sendStopTracking()
                    }) {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal)
                
                // Flight Data Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 15) {
                    // Altitude
                    DataCard(
                        title: "ALTITUDE",
                        value: "\(Int(flightDataManager.altitude))",
                        unit: "ft",
                        icon: "arrow.up.to.line"
                    )
                    
                    // Speed
                    DataCard(
                        title: "SPEED",
                        value: "\(Int(flightDataManager.groundSpeed))",
                        unit: "kt",
                        icon: "speedometer"
                    )
                    
                    // Heading
                    DataCard(
                        title: "HEADING",
                        value: "\(Int(flightDataManager.heading))°",
                        unit: "",
                        icon: "safari"
                    )
                    
                    // Vertical Speed
                    DataCard(
                        title: "V/S",
                        value: flightDataManager.verticalSpeed >= 0 ? "+\(Int(flightDataManager.verticalSpeed))" : "\(Int(flightDataManager.verticalSpeed))",
                        unit: "fpm",
                        icon: flightDataManager.verticalSpeed >= 0 ? "arrow.up" : "arrow.down"
                    )
                    
                    // Pressure
                    DataCard(
                        title: "QNH",
                        value: "\(flightDataManager.pressure, specifier: "%.2f")",
                        unit: "inHg",
                        icon: "gauge"
                    )
                    
                    // Track
                    DataCard(
                        title: "TRACK",
                        value: "\(Int(flightDataManager.track))°",
                        unit: "",
                        icon: "location.north.line"
                    )
                }
                .padding(.horizontal)
            }
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
        .navigationBarHidden(true)
    }
}

struct DataCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: icon)
                .font(.system(size: 10))
                .foregroundColor(.gray)
            
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(10)
    }
}