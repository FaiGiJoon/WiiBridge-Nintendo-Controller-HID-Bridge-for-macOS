import SwiftUI
import IOBluetooth

struct DeviceDetailView: View {
    let device: IOBluetoothDevice
    @State private var wiiState = WiiState()
    @State private var controllerType: WiiDevice.ControllerType = .wiiRemote

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection

                Divider()

                if controllerType == .uDraw {
                    uDrawVisualizer
                } else {
                    standardVisualizer
                }

                Divider()

                DolphinOptimizationView()
            }
            .padding()
        }
        .onAppear {
            setupObservation()
        }
        .id(device.addressString) // Ensure view refreshes when switching devices
    }

    var headerSection: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(device.name ?? "Wii Remote")
                    .font(.title)
                Text(device.addressString)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                HStack {
                    Image(systemName: "battery.100")
                    Text("\(Int(wiiState.batteryLevel * 100))%")
                }
                .font(.headline)
                Text(String(describing: controllerType).capitalized)
                    .font(.caption)
                    .padding(4)
                    .background(Color.accentColor.opacity(0.2))
                    .cornerRadius(4)
            }
        }
    }

    var uDrawVisualizer: some View {
        VStack(alignment: .leading) {
            Text("uDraw Tablet Surface")
                .font(.headline)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary, lineWidth: 2)
                    .background(Color.gray.opacity(0.1))

                if wiiState.uDrawX < 1.0 {
                    GeometryReader { geo in
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 20, height: 20)
                            .scaleEffect(0.5 + wiiState.uDrawPressure)
                            .position(
                                x: CGFloat(wiiState.uDrawX) * geo.size.width,
                                y: CGFloat(wiiState.uDrawY) * geo.size.height
                            )
                    }
                } else {
                    Text("Stylus Away")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(height: 300)

            HStack {
                IndicatorView(label: "Upper Button", active: wiiState.uDrawButtonUpper)
                IndicatorView(label: "Lower Button", active: wiiState.uDrawButtonLower)
                Spacer()
                Text("Pressure: \(Int(wiiState.uDrawPressure * 100))%")
            }
        }
    }

    var standardVisualizer: some View {
        VStack(alignment: .leading) {
            Text("Wiimote Inputs")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))]) {
                IndicatorView(label: "A", active: wiiState.buttonA)
                IndicatorView(label: "B", active: wiiState.buttonB)
                IndicatorView(label: "1", active: wiiState.buttonOne)
                IndicatorView(label: "2", active: wiiState.buttonTwo)
                IndicatorView(label: "Home", active: wiiState.buttonHome)
                IndicatorView(label: "+", active: wiiState.buttonPlus)
                IndicatorView(label: "-", active: wiiState.buttonMinus)
                IndicatorView(label: "Up", active: wiiState.dpadUp)
                IndicatorView(label: "Down", active: wiiState.dpadDown)
                IndicatorView(label: "Left", active: wiiState.dpadLeft)
                IndicatorView(label: "Right", active: wiiState.dpadRight)
            }
        }
    }

    func setupObservation() {
        if let connection = BluetoothManager.shared.connection(for: device) {
            connection.wiiDevice.addObserver { state in
                Task { @MainActor in
                    self.wiiState = state
                    self.controllerType = connection.wiiDevice.type
                }
            }
        }
    }
}
