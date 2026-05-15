import Foundation
import IOBluetooth

@MainActor
class BluetoothManager: NSObject, IOBluetoothDeviceInquiryDelegate, IOBluetoothDevicePairDelegate {
    static let shared = BluetoothManager()
    
    private var inquiry: IOBluetoothDeviceInquiry?
    private var devices: [IOBluetoothDevice] = []
    private var activeConnections: [String: WiiConnection] = [:]
    
    private var deviceFoundContinuation: AsyncStream<IOBluetoothDevice>.Continuation?
    
    func scan() -> AsyncStream<IOBluetoothDevice> {
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

    func connect(device: IOBluetoothDevice) async throws -> WiiConnection {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.pairingContinuation = continuation
            let pair = IOBluetoothDevicePair(device: device)
            pair?.delegate = self
            let status = pair?.start() ?? kIOReturnError
            if status != kIOReturnSuccess {
                continuation.resume(throwing: NSError(domain: NSOSStatusErrorDomain, code: Int(status)))
                self.pairingContinuation = nil
            }
        }

        let connection = WiiConnection(device: device)
        self.activeConnections[device.addressString] = connection
        try await connection.connect()
        return connection
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
