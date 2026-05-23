import Foundation
#if os(macOS)
import IOBluetooth

@MainActor
class BluetoothManager: NSObject, ObservableObject, IOBluetoothDeviceInquiryDelegate, IOBluetoothDevicePairDelegate, BluetoothProvider {
    static let shared = BluetoothManager()
    
    private var inquiry: IOBluetoothDeviceInquiry?
    private var devices: [IOBluetoothDevice] = []
    @Published var activeConnections: [String: WiiConnection] = [:]
    
    private var deviceFoundContinuation: AsyncStream<BluetoothDevice>.Continuation?
    
    func scan() -> AsyncStream<BluetoothDevice> {
        AsyncStream { continuation in
            self.deviceFoundContinuation = continuation
            inquiry = IOBluetoothDeviceInquiry(delegate: self)
            inquiry?.start()

            continuation.onTermination = { @Sendable _ in
                Task { @MainActor in
                    self.stopScanning()
                }
            }
        }
    }
    
    func stopScanning() {
        inquiry?.stop()
        inquiry = nil
        deviceFoundContinuation?.finish()
        deviceFoundContinuation = nil
    }
    
    func deviceInquiryDeviceFound(_ inquiry: IOBluetoothDeviceInquiry!, device: IOBluetoothDevice!) {
        guard let name = device.name else { return }
        if name.contains("Nintendo") || name.contains("RVL") {
            if !self.devices.contains(where: { $0.addressString == device.addressString }) {
                self.devices.append(device)
                self.deviceFoundContinuation?.yield(device)
            }
        }
    }
    
    private var pairingContinuation: CheckedContinuation<Void, Error>?

    func connection(for device: IOBluetoothDevice) -> WiiConnection? {
        return activeConnections[device.addressString]
    }

    func connect(device: BluetoothDevice) async throws -> L2CAPChannelGroup {
        guard let ioDevice = device as? IOBluetoothDevice else {
            throw NSError(domain: "WiiBridge", code: -1)
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.pairingContinuation = continuation
            let pair = IOBluetoothDevicePair(device: ioDevice)
            pair?.delegate = self
            let status = pair?.start() ?? kIOReturnError
            if status != kIOReturnSuccess {
                continuation.resume(throwing: NSError(domain: NSOSStatusErrorDomain, code: Int(status)))
                self.pairingContinuation = nil
            }
        }

        let group = MacOSL2CAPChannelGroup(device: ioDevice)
        try await group.connect()
        return group
    }

    func registerConnection(_ connection: WiiConnection) {
        self.activeConnections[connection.device.addressString] = connection
    }
    
    // MARK: - IOBluetoothDevicePairDelegate
    
    func devicePairingPINCodeRequest(_ sender: Any!) {
        guard let pair = sender as? IOBluetoothDevicePair,
              let device = pair.device() else { return }
        
        let pinData = calculatePIN(device: device, type: .syncButton)
        var pinCode = BluetoothPINCode()
        pinData.withUnsafeBytes { ptr in
            if let baseAddress = ptr.baseAddress {
                memcpy(&pinCode, baseAddress, pinData.count)
            }
        }
        
        pair.replyPINCode(UInt8(pinData.count), pinCode: pinCode)
    }
    
    func devicePairingFinished(_ sender: Any!, error: IOReturn) {
        if error == kIOReturnSuccess {
            pairingContinuation?.resume()
        } else {
            pairingContinuation?.resume(throwing: NSError(domain: NSOSStatusErrorDomain, code: Int(error)))
        }
        pairingContinuation = nil
    }
    
    func calculatePIN(device: IOBluetoothDevice, type: PINType) -> Data {
        var address = BluetoothDeviceAddress()
        switch type {
        case .syncButton:
            device.getAddress(&address)
            return Data([address.data.5, address.data.4, address.data.3, address.data.2, address.data.1, address.data.0])
        case .buttons1And2:
            IOBluetoothHostController.default().getAddress(&address)
            return Data([address.data.0, address.data.1, address.data.2, address.data.3, address.data.4, address.data.5])
        }
    }
    
    enum PINType {
        case syncButton
        case buttons1And2
    }
}

extension IOBluetoothDevice: BluetoothDevice {}

class MacOSL2CAPChannelGroup: NSObject, L2CAPChannelGroup, IOBluetoothL2CAPChannelDelegate {
    var controlChannel: L2CAPChannel?
    var interruptChannel: L2CAPChannel?
    private let device: IOBluetoothDevice
    private var connectionContinuation: CheckedContinuation<Void, Error>?
    private var controlChannelOpen = false
    private var interruptChannelOpen = false

    init(device: IOBluetoothDevice) { self.device = device }

    func connect() async throws {
        device.openConnection()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.connectionContinuation = continuation
            var control: IOBluetoothL2CAPChannel?
            var interrupt: IOBluetoothL2CAPChannel?
            let controlStatus = device.openL2CAPChannelAsync(&control, withPSM: 0x11, delegate: self)
            let interruptStatus = device.openL2CAPChannelAsync(&interrupt, withPSM: 0x13, delegate: self)
            if controlStatus != kIOReturnSuccess || interruptStatus != kIOReturnSuccess {
                continuation.resume(throwing: NSError(domain: NSOSStatusErrorDomain, code: Int(controlStatus)))
            } else {
                self.controlChannel = MacOSL2CAPChannel(channel: control!)
                self.interruptChannel = MacOSL2CAPChannel(channel: interrupt!)
            }
        }
    }

    func disconnect() {
        (controlChannel as? MacOSL2CAPChannel)?.channel.close()
        (interruptChannel as? MacOSL2CAPChannel)?.channel.close()
    }

    func l2capChannelOpenComplete(_ l2capChannel: IOBluetoothL2CAPChannel!, status: IOReturn) {
        if status == kIOReturnSuccess {
            if l2capChannel == (controlChannel as? MacOSL2CAPChannel)?.channel { controlChannelOpen = true }
            else if l2capChannel == (interruptChannel as? MacOSL2CAPChannel)?.channel { interruptChannelOpen = true }
            if controlChannelOpen && interruptChannelOpen {
                connectionContinuation?.resume()
                connectionContinuation = nil
            }
        } else {
            connectionContinuation?.resume(throwing: NSError(domain: NSOSStatusErrorDomain, code: Int(status)))
            connectionContinuation = nil
        }
    }

    func l2capChannelData(_ l2capChannel: IOBluetoothL2CAPChannel!, data dataPointer: UnsafeMutableRawPointer!, length dataLength: Int) {
        let data = Data(bytes: dataPointer, count: dataLength)
        if l2capChannel == (controlChannel as? MacOSL2CAPChannel)?.channel { controlChannel?.onData?(data) }
        else { interruptChannel?.onData?(data) }
    }

    func l2capChannelClosed(_ l2capChannel: IOBluetoothL2CAPChannel!) {
        if l2capChannel == (controlChannel as? MacOSL2CAPChannel)?.channel { controlChannel?.onClosed?() }
        else { interruptChannel?.onClosed?() }
    }
}

class MacOSL2CAPChannel: L2CAPChannel {
    let channel: IOBluetoothL2CAPChannel
    var onData: ((Data) -> Void)?
    var onClosed: (() -> Void)?
    init(channel: IOBluetoothL2CAPChannel) { self.channel = channel }
    func send(data: Data) {
        var bytes = [UInt8](data)
        channel.writeAsync(&bytes, length: UInt16(bytes.count), refCon: nil)
    }
}
#endif
