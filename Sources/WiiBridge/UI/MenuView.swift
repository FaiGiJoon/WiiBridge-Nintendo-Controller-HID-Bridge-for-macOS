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
    @State private var connectedDevices: [String] = []
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
                
                ForEach(connectedDevices, id: \.self) { name in
                    HStack {
                        Image(systemName: "gamecontroller.fill")
                        Text(name)
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
            BluetoothManager.shared.onDeviceFound = { device in
                if !foundDevices.contains(where: { $0.addressString == device.addressString }) {
                    foundDevices.append(device)
                }
            }
            BluetoothManager.shared.startScanning()
        } else {
            BluetoothManager.shared.stopScanning()
        }
    }
    
    func pairDevice(_ device: IOBluetoothDevice) {
        BluetoothManager.shared.connect(device: device)
        if let name = device.name {
            connectedDevices.append(name)
            foundDevices.removeAll(where: { $0.addressString == device.addressString })
        }
    }
}
