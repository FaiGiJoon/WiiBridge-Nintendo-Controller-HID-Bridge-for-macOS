import Foundation

#if !os(macOS)
@main
struct WiiBridgeCLI {
    static func main() async throws {
        print("WiiBridge CLI starting...")
        let provider: BluetoothProvider
        let controllerProvider: VirtualControllerProvider
        #if os(Linux)
        provider = LinuxBluetoothProvider()
        controllerProvider = LinuxVirtualControllerProvider()
        #elseif os(Windows)
        provider = WindowsBluetoothProvider()
        controllerProvider = WindowsVirtualControllerProvider()
        #else
        fatalError("Unsupported platform")
        #endif

        for await device in provider.scan() {
            print("Found: \(device.name ?? "Unknown") (\(device.addressString))")
            let connection = WiiConnection(device: device, provider: provider)
            connection.wiiDevice.virtualController = controllerProvider
            try? await connection.connect()
        }
        try await Task.sleep(nanoseconds: UInt64.max)
    }
}
#endif
