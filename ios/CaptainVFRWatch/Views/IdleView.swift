import SwiftUI

struct IdleView: View {
    @StateObject private var flightDataManager = FlightDataManager.shared
    @State private var currentTime = Date()
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private var zuluTimeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        return formatter
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        return formatter
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Zulu Time Display
            VStack(spacing: 5) {
                Text(zuluTimeFormatter.string(from: currentTime))
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                
                Text(dateFormatter.string(from: currentTime))
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            
            // Current Altitude & Pressure
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 5) {
                    Label("ALT", systemImage: "arrow.up.to.line")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    Text("\(Int(flightDataManager.altitude)) ft")
                        .font(.system(size: 16, weight: .semibold))
                }
                
                VStack(alignment: .leading, spacing: 5) {
                    Label("QNH", systemImage: "gauge")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    Text("\(flightDataManager.pressure, specifier: "%.2f")")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            
            // Start Tracking Button
            Button(action: {
                flightDataManager.startTracking()
                WatchConnectivityManager.shared.sendStartTracking()
            }) {
                HStack {
                    Image(systemName: "airplane")
                    Text("Start Tracking")
                }
                .foregroundColor(.black)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            .background(Color.green)
            .cornerRadius(20)
        }
        .padding()
        .onReceive(timer) { _ in
            currentTime = Date()
        }
        .navigationBarHidden(true)
    }
}