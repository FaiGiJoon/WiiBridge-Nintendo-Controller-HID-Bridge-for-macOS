import Foundation
#if os(Linux)
import Glibc

class LinuxBluetoothProvider: BluetoothProvider {
    func scan() -> AsyncStream<BluetoothDevice> {
        AsyncStream { continuation in
            print("Linux Bluetooth scanning for Nintendo devices...")
            // Implementation would use HCI inquiry.
            // Yielding a mock device to verify the cross-platform flow works.
            let mockDevice = LinuxBluetoothDevice(name: "Nintendo RVL-CNT-01 (Mock)", address: "00:1E:35:00:00:00")
            continuation.yield(mockDevice)
        }
    }

    func stopScanning() {}

    func connect(device: BluetoothDevice) async throws -> L2CAPChannelGroup {
        let group = LinuxL2CAPChannelGroup(address: device.addressString)
        try group.connect()
        return group
    }
}

class LinuxBluetoothDevice: BluetoothDevice {
    var name: String?
    var addressString: String
    init(name: String?, address: String) { self.name = name; self.addressString = address }
}

class LinuxL2CAPChannelGroup: L2CAPChannelGroup {
    var controlChannel: L2CAPChannel?
    var interruptChannel: L2CAPChannel?
    let address: String

    init(address: String) { self.address = address }

    func connect() throws {
        let control = LinuxL2CAPChannel(address: address, psm: 0x11)
        let interrupt = LinuxL2CAPChannel(address: address, psm: 0x13)
        try control.open()
        try interrupt.open()
        self.controlChannel = control
        self.interruptChannel = interrupt
    }

    func disconnect() {
        (controlChannel as? LinuxL2CAPChannel)?.close()
        (interruptChannel as? LinuxL2CAPChannel)?.close()
    }
}

class LinuxL2CAPChannel: L2CAPChannel {
    private var fd: Int32 = -1
    private let address: String
    private let psm: UInt16
    var onData: ((Data) -> Void)?
    var onClosed: (() -> Void)?

    init(address: String, psm: UInt16) {
        self.address = address
        self.psm = psm
    }

    func open() throws {
        // AF_BLUETOOTH = 31, SOCK_SEQPACKET = 5
        fd = socket(31, 5, 0)
        guard fd >= 0 else { throw NSError(domain: "LinuxBluetooth", code: Int(errno)) }
        print("Linux: Socket created for \(address) PSM \(psm).")
        Thread { [weak self] in self?.readLoop() }.start()
    }

    func send(data: Data) {
        guard fd != -1 else { return }
        data.withUnsafeBytes { _ = Glibc.write(fd, $0.baseAddress, data.count) }
    }

    private func readLoop() {
        var buffer = [UInt8](repeating: 0, count: 1024)
        while fd != -1 {
            let bytesRead = Glibc.read(fd, &buffer, buffer.count)
            if bytesRead > 0 {
                let data = Data(buffer[0..<bytesRead])
                DispatchQueue.main.async { [weak self] in self?.onData?(data) }
            } else if bytesRead <= 0 {
                DispatchQueue.main.async { [weak self] in self?.close() }
                break
            }
        }
    }

    func close() {
        if fd != -1 {
            let f = fd; fd = -1
            Glibc.close(f)
            onClosed?()
        }
    }
}
#endif
