import SwiftUI
import IOBluetooth

struct SidebarView: View {
    @Binding var selectedDevice: IOBluetoothDevice?
    @StateObject private var bluetoothManager = BluetoothManager.shared
    @State private var discoveredDevices: [IOBluetoothDevice] = []
    @State private var isScanning = false

    var body: some View {
        List(selection: $selectedDevice) {
            Section("Connected Controllers") {
                if bluetoothManager.activeConnections.isEmpty {
                    Text("No controllers connected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(Array(bluetoothManager.activeConnections.keys), id: \.self) { address in
                        if let connection = bluetoothManager.activeConnections[address] {
                            NavigationLink(value: connection.device) {
                                Label(connection.device.name ?? "Wii Remote", systemImage: "gamecontroller.fill")
                            }
                        }
                    }
                }
            }

            Section("Discovered Devices") {
                ForEach(discoveredDevices, id: \.addressString) { device in
                    if bluetoothManager.activeConnections[device.addressString] == nil {
                        HStack {
                            Label(device.name ?? "Wii Remote", systemImage: "gamecontroller")
                            Spacer()
                            Button("Pair") {
                                pairDevice(device)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: toggleScanning) {
                HStack {
                    Image(systemName: isScanning ? "stop.fill" : "play.fill")
                    Text(isScanning ? "Stop Scanning" : "Scan for Devices")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
    }

    func toggleScanning() {
        isScanning.toggle()
        if isScanning {
            Task {
                for await device in bluetoothManager.scan() {
                    if !discoveredDevices.contains(where: { $0.addressString == device.addressString }) {
                        discoveredDevices.append(device)
                    }
                }
            }
        } else {
            bluetoothManager.stopScanning()
        }
    }

    func pairDevice(_ device: IOBluetoothDevice) {
        Task {
            do {
                _ = try await bluetoothManager.connect(device: device)
                // Device will appear in Connected Controllers section via @Published update
            } catch {
                print("Failed to pair: \(error)")
            }
        }
    }
}
