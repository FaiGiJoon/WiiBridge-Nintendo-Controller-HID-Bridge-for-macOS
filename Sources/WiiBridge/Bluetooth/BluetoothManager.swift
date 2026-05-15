import Foundation
import IOBluetooth

class BluetoothManager: NSObject, IOBluetoothDeviceInquiryDelegate, IOBluetoothDevicePairDelegate {
    static let shared = BluetoothManager()
    
    private var inquiry: IOBluetoothDeviceInquiry?
    private var devices: [IOBluetoothDevice] = []
    private var activeConnections: [String: WiiConnection] = [:]
    
    var onDeviceFound: ((IOBluetoothDevice) -> Void)?
    
    func startScanning() {
        inquiry = IOBluetoothDeviceInquiry(delegate: self)
        inquiry?.start()
    }
    
    func stopScanning() {
        inquiry?.stop()
    }
    
    func deviceInquiryDeviceFound(_ inquiry: IOBluetoothDeviceInquiry!, device: IOBluetoothDevice!) {
        guard let name = device.name else { return }
        if name.contains("Nintendo") || name.contains("RVL") {
            DispatchQueue.main.async {
                if !self.devices.contains(where: { $0.addressString == device.addressString }) {
                    self.devices.append(device)
                    self.onDeviceFound?(device)
                }
            }
        }
    }
    
    func connect(device: IOBluetoothDevice) {
        let pair = IOBluetoothDevicePair(device: device)
        pair?.delegate = self
        pair?.start()
    }
    
    // MARK: - IOBluetoothDevicePairDelegate
    
    func devicePairingPINCodeRequest(_ sender: Any!) {
        guard let pair = sender as? IOBluetoothDevicePair,
              let device = pair.device() else { return }
        
        let pinData = calculatePIN(device: device, type: .syncButton)
        let pinCode = BluetoothPINCode(data: (
            pinData[0], pinData[1], pinData[2], pinData[3], pinData[4], pinData[5],
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        ))
        
        pair.replyPINCode(UInt8(pinData.count), pinCode: pinCode)
    }
    
    func devicePairingFinished(_ sender: Any!, error: IOReturn) {
        guard error == kIOReturnSuccess,
              let pair = sender as? IOBluetoothDevicePair,
              let device = pair.device() else {
            print("Pairing failed with error: \(error)")
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let connection = WiiConnection(device: device)
            self.activeConnections[device.addressString] = connection
            connection.connect()
        }
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
