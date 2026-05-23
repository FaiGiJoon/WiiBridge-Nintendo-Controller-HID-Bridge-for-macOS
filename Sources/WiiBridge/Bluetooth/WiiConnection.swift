import Foundation

@MainActor
class WiiConnection {
    let device: BluetoothDevice
    var channelGroup: L2CAPChannelGroup?
    let wiiDevice = WiiDevice()
    
    private var isConnected = false
    private let provider: BluetoothProvider

    init(device: BluetoothDevice, provider: BluetoothProvider) {
        self.device = device
        self.provider = provider
    }
    
    func connect() async throws {
        self.channelGroup = try await provider.connect(device: device)

        channelGroup?.controlChannel?.onData = { [weak self] data in
            self?.wiiDevice.parse(data: data)
        }
        
        channelGroup?.interruptChannel?.onData = { [weak self] data in
            self?.wiiDevice.parse(data: data)
        }
        
        channelGroup?.controlChannel?.onClosed = { [weak self] in
            self?.handleDisconnection()
        }
        
        channelGroup?.interruptChannel?.onClosed = { [weak self] in
            self?.handleDisconnection()
        }

        isConnected = true
        wiiDevice.connection = self
        wiiDevice.initialize()
    }
    
    func send(data: Data) {
        channelGroup?.controlChannel?.send(data: data)
    }

    private var isReconnecting = false

    private func handleDisconnection() {
        guard isConnected && !isReconnecting else { return }
        isConnected = false
        isReconnecting = true

        print("Device disconnected, attempting to reconnect...")

        Task {
            while isReconnecting {
                do {
                    try await Task.sleep(nanoseconds: 2 * 1_000_000_000)
                    try await connect()
                    isReconnecting = false
                    print("Reconnected successfully")
                } catch {
                    print("Reconnection attempt failed, retrying...")
                }
            }
        }
    }
}
