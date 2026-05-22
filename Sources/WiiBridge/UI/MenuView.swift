import SwiftUI
import IOBluetooth

struct Profile: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let description: String
}

struct MenuView: View {
    @State private var isScanning = false
    @State private var foundDevices: [IOBluetoothDevice] = []
    @State private var connectedDevices: [IOBluetoothDevice] = []
    @State private var batteryLevels: [String: Double] = [:]
    @State private var selectedProfile: Profile = Profile(name: "Standard", description: "Default Wii Layout")
    
    let profiles = [
        Profile(name: "Standard", description: "Default Wii Layout"),
        Profile(name: "Xbox Layout", description: "Maps Wii U Pro to Xbox buttons"),
        Profile(name: "Classic", description: "Optimized for SNES/NES games")
    ]
    
    var body: some View {
        VStack(spacing: 10) {
            Text("Wii Bridge")
                .font(.headline)
            
            Divider()
            
            Button(action: {
                toggleScanning()
            }) {
                HStack {
                    Image(systemName: isScanning ? "stop.fill" : "play.fill")
                    Text(isScanning ? "Stop Scanning" : "Pair New Device")
                }
            }
            
            if !foundDevices.isEmpty {
                Divider()
                Text("Found Devices:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ForEach(foundDevices, id: \.addressString) { device in
                    HStack {
                        Text(device.name ?? "Unknown")
                        Spacer()
                        Button("Pair") {
                            pairDevice(device)
                        }
                    }
                }
            }
            
            if !connectedDevices.isEmpty {
                Divider()
                Text("Connected Controllers:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ForEach(connectedDevices, id: \.addressString) { device in
                    HStack {
                        Image(systemName: "gamecontroller.fill")
                        VStack(alignment: .leading) {
                            Text(device.name ?? "Wii Remote")
                            if let battery = batteryLevels[device.addressString] {
                                Text("\(Int(battery * 100))%")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Text("Connected").font(.caption).foregroundColor(.green)
                    }
                }
            }
            
            Divider()
            
            VStack(alignment: .leading) {
                Text("Button Profile")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Picker("", selection: $selectedProfile) {
                    ForEach(profiles) { profile in
                        Text(profile.name).tag(profile)
                    }
                }
                .pickerStyle(.menu)
            }
            
            Divider()
            
            Button("Open Main Dashboard") {
                (NSApplication.shared.delegate as? AppDelegate)?.openMainWindow()
            }

            Button("Quit Wii Bridge") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
        .frame(width: 250)
    }
    
    func toggleScanning() {
        isScanning.toggle()
        if isScanning {
            Task {
                for await device in BluetoothManager.shared.scan() {
                    if !foundDevices.contains(where: { $0.addressString == device.addressString }) {
                        foundDevices.append(device)
                    }
                }
            }
        } else {
            BluetoothManager.shared.stopScanning()
        }
    }
    
    func pairDevice(_ device: IOBluetoothDevice) {
        Task {
            do {
                let connection = try await BluetoothManager.shared.connect(device: device)
                connectedDevices.append(device)
                foundDevices.removeAll(where: { $0.addressString == device.addressString })

                connection.wiiDevice.addObserver { state in
                    batteryLevels[device.addressString] = state.batteryLevel
                }
            } catch {
                print("Failed to pair: \(error)")
            }
        }
    }
}
