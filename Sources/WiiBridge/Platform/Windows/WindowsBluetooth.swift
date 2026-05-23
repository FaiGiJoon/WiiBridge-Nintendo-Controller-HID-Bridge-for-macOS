import Foundation
#if os(Windows)
import WinSDK

class WindowsBluetoothProvider: BluetoothProvider {
    func scan() -> AsyncStream<BluetoothDevice> {
        AsyncStream { continuation in
            print("Windows HID discovery started...")
            let mockDevice = WindowsBluetoothDevice(name: "Nintendo RVL-CNT-01 (Mock)", address: "\\\\?\\hid#mock")
            continuation.yield(mockDevice)
        }
    }

    func stopScanning() {}

    func connect(device: BluetoothDevice) async throws -> L2CAPChannelGroup {
        let group = WindowsHIDChannelGroup(devicePath: device.addressString)
        try group.connect()
        return group
    }
}

class WindowsBluetoothDevice: BluetoothDevice {
    var name: String?
    var addressString: String
    init(name: String?, address: String) { self.name = name; self.addressString = address }
}

class WindowsHIDChannelGroup: L2CAPChannelGroup {
    var controlChannel: L2CAPChannel?
    var interruptChannel: L2CAPChannel?
    let devicePath: String
    init(devicePath: String) { self.devicePath = devicePath }
    func connect() throws {
        let channel = WindowsHIDChannel(devicePath: devicePath)
        try channel.open()
        self.controlChannel = channel
        self.interruptChannel = channel
    }
    func disconnect() { (controlChannel as? WindowsHIDChannel)?.close() }
}

class WindowsHIDChannel: L2CAPChannel {
    private var handle: HANDLE?
    private let devicePath: String
    var onData: ((Data) -> Void)?
    var onClosed: (() -> Void)?

    init(devicePath: String) { self.devicePath = devicePath }

    func open() throws {
        let h = devicePath.withCString(encodedAs: UTF16.self) { CreateFileW($0, UInt32(GENERIC_READ | GENERIC_WRITE), UInt32(FILE_SHARE_READ | FILE_SHARE_WRITE), nil, UInt32(OPEN_EXISTING), 0, nil) }
        if h == INVALID_HANDLE_VALUE { throw NSError(domain: "WindowsHID", code: Int(GetLastError())) }
        self.handle = h
        Thread { [weak self] in self?.readLoop() }.start()
    }

    func send(data: Data) {
        guard let h = handle else { return }
        var bytesWritten: UInt32 = 0
        var reportData = data
        _ = reportData.withUnsafeMutableBytes { WriteFile(h, $0.baseAddress, UInt32(data.count), &bytesWritten, nil) }
    }

    private func readLoop() {
        var buffer = [UInt8](repeating: 0, count: 64)
        var bytesRead: UInt32 = 0
        while let h = handle {
            if ReadFile(h, &buffer, UInt32(buffer.count), &bytesRead, nil) && bytesRead > 0 {
                let data = Data(buffer[0..<Int(bytesRead)])
                DispatchQueue.main.async { [weak self] in self?.onData?(data) }
            } else {
                DispatchQueue.main.async { [weak self] in self?.close() }
                break
            }
        }
    }

    func close() {
        if let h = handle { handle = nil; CloseHandle(h); onClosed?() }
    }
}
#endif
