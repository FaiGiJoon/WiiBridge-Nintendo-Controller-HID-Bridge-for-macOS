import SwiftUI

#if os(macOS)
struct MenuView: View {
    @ObservedObject var bluetoothManager = BluetoothManager.shared
    @State private var isScanning = false

    var body: some View {
        VStack(spacing: 10) {
            Text("WiiBridge")
                .font(.headline)
            Divider()
            if isScanning { ProgressView("Scanning...") }
            else { Button("Pair New Device") { startScan() } }
            Divider()
            ForEach(Array(bluetoothManager.activeConnections.values), id: \.device.addressString) { conn in
                HStack {
                    Text(conn.device.name ?? "Wii Remote")
                    Spacer()
                    Text("\(Int(conn.wiiDevice.state.batteryLevel * 100))%")
                }
            }
            Button("Open Main Dashboard") { AppDelegate.shared?.openMainWindow() }
            Button("Quit") { NSApp.terminate(nil) }
        }
        .padding()
        .frame(width: 250)
    }
    
    func startScan() {
        isScanning = true
        Task {
            let scanStream = bluetoothManager.scan()
            for await device in scanStream {
                do {
                    let connection = WiiConnection(device: device, provider: bluetoothManager)
                    connection.wiiDevice.virtualController = VirtualControllerBridge.shared
                    VirtualControllerBridge.shared.addDevice(connection.wiiDevice)
                    try await connection.connect()
                    bluetoothManager.registerConnection(connection)
                } catch {
                    print("Connection failed for \(device.addressString): \(error)")
                }
            }
            isScanning = false
        }
    }
}
#endif
