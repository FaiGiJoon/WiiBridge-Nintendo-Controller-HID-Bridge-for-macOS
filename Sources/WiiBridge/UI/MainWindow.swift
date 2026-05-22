import SwiftUI
import IOBluetooth

struct MainWindow: View {
    @State private var selectedDevice: IOBluetoothDevice?

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedDevice: $selectedDevice)
        } detail: {
            if let device = selectedDevice {
                DeviceDetailView(device: device)
            } else {
                ContentUnavailableView("No Controller Selected", systemImage: "gamecontroller", description: Text("Select a controller from the sidebar to view details and settings."))
            }
        }
        .frame(minWidth: 700, minHeight: 500)
    }
}
