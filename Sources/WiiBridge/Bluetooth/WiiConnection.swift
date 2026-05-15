import Foundation
import IOBluetooth

class WiiConnection: NSObject, IOBluetoothL2CAPChannelDelegate {
    let device: IOBluetoothDevice
    var controlChannel: IOBluetoothL2CAPChannel?
    var interruptChannel: IOBluetoothL2CAPChannel?
    let wiiDevice = WiiDevice()
    
    private var controlChannelOpen = false
    private var interruptChannelOpen = false
    
    init(device: IOBluetoothDevice) {
        self.device = device
        super.init()
    }
    
    func connect() {
        device.openConnection()
        device.openL2CAPChannelAsync(&controlChannel, withPSM: 0x11, delegate: self)
        device.openL2CAPChannelAsync(&interruptChannel, withPSM: 0x13, delegate: self)
        
        wiiDevice.connection = self
    }
    
    func send(data: Data) {
        guard let controlChannel = controlChannel, controlChannelOpen else { return }
        var bytes = [UInt8](data)
        controlChannel.writeAsync(&bytes, length: UInt16(bytes.count), refCon: nil)
    }
    
    // MARK: - IOBluetoothL2CAPChannelDelegate
    
    func l2capChannelOpenComplete(_ l2capChannel: IOBluetoothL2CAPChannel!, status: IOReturn) {
        guard status == kIOReturnSuccess else {
            print("Failed to open L2CAP channel: \(status)")
            return
        }
        
        if l2capChannel == controlChannel {
            controlChannelOpen = true
        } else if l2capChannel == interruptChannel {
            interruptChannelOpen = true
        }
        
        if controlChannelOpen && interruptChannelOpen {
            wiiDevice.initialize()
            VirtualControllerBridge.shared.addDevice(wiiDevice)
        }
    }
    
    func l2capChannelData(_ l2capChannel: IOBluetoothL2CAPChannel!, data dataPointer: UnsafeMutableRawPointer!, length dataLength: Int) {
        let data = Data(bytes: dataPointer, count: dataLength)
        wiiDevice.parse(data: data)
    }
}
