import SwiftUI

struct DolphinOptimizationView: View {
    @AppStorage("dolphinOptimized") private var isOptimized = true
    @AppStorage("emulateUDraw") private var emulateUDraw = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Dolphin Emulator Optimization", systemImage: "bolt.fill")
                .font(.headline)
                .foregroundColor(.accentColor)

            Toggle("Enable Dolphin Compatibility Mode", isOn: $isOptimized)
                .help("Adjusts HID report rates and stick deadzones for better performance in Dolphin.")

            Toggle("Emulate uDraw Tablet via Virtual Joystick", isOn: $emulateUDraw)
                .help("Maps the uDraw tablet surface to a virtual analog stick that Dolphin can easily recognize.")

            if isOptimized {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Recommended Dolphin Settings:")
                        .font(.caption)
                        .fontWeight(.bold)
                    Text("• Controller Type: Emulated Wii Remote")
                    Text("• Extension: uDraw Tablet")
                    Text("• Mapping: Select 'WiiBridge' from the Device dropdown")
                }
                .padding()
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(8)
                .font(.caption)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

struct SettingsView: View {
    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at Login", isOn: .constant(false))
                Toggle("Show in Menu Bar", isOn: .constant(true))
            }

            Section("Dolphin Support") {
                DolphinOptimizationView()
            }
        }
        .padding()
        .frame(width: 400, height: 300)
    }
}
