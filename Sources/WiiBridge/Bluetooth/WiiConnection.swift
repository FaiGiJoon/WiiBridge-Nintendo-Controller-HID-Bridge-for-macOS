import Foundation
import IOBluetooth

@MainActor
class WiiConnection: NSObject, IOBluetoothL2CAPChannelDelegate {
    let device: IOBluetoothDevice
    var controlChannel: IOBluetoothL2CAPChannel?
    var interruptChannel: IOBluetoothL2CAPChannel?
    let wiiDevice = WiiDevice()
    
    private var controlChannelOpen = false
    private var interruptChannelOpen = false
    
    private var connectionContinuation: CheckedContinuation<Void, Error>?

    init(device: IOBluetoothDevice) {
        self.device = device
        super.init()
    }
    
    func connect() async throws {
        device.openConnection()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.connectionContinuation = continuation

            let controlStatus = device.openL2CAPChannelAsync(&controlChannel, withPSM: 0x11, delegate: self)
            let interruptStatus = device.openL2CAPChannelAsync(&interruptChannel, withPSM: 0x13, delegate: self)

            if controlStatus != kIOReturnSuccess || interruptStatus != kIOReturnSuccess {
                continuation.resume(throwing: NSError(domain: NSOSStatusErrorDomain, code: Int(controlStatus != kIOReturnSuccess ? controlStatus : interruptStatus)))
                self.connectionContinuation = nil
            }
        }
        
        wiiDevice.connection = self
        wiiDevice.initialize()
        VirtualControllerBridge.shared.addDevice(wiiDevice)
    }
    
    func send(data: Data) {
        guard let controlChannel = controlChannel, controlChannelOpen else { return }
        var bytes = [UInt8](data)
        controlChannel.writeAsync(&bytes, length: UInt16(bytes.count), refCon: nil)
    }
    
    // MARK: - IOBluetoothL2CAPChannelDelegate
    
    func l2capChannelOpenComplete(_ l2capChannel: IOBluetoothL2CAPChannel!, status: IOReturn) {
        guard status == kIOReturnSuccess else {
            connectionContinuation?.resume(throwing: NSError(domain: NSOSStatusErrorDomain, code: Int(status)))
            connectionContinuation = nil
            return
        }
        
        if l2capChannel == controlChannel {
            controlChannelOpen = true
        } else if l2capChannel == interruptChannel {
            interruptChannelOpen = true
        }
        
        if controlChannelOpen && interruptChannelOpen {
            connectionContinuation?.resume()
            connectionContinuation = nil
        }
    }
    
    func l2capChannelData(_ l2capChannel: IOBluetoothL2CAPChannel!, data dataPointer: UnsafeMutableRawPointer!, length dataLength: Int) {
        let data = Data(bytes: dataPointer, count: dataLength)
        wiiDevice.parse(data: data)
    }

    func l2capChannelClosed(_ l2capChannel: IOBluetoothL2CAPChannel!) {
        if l2capChannel == controlChannel {
            controlChannelOpen = false
        } else if l2capChannel == interruptChannel {
            interruptChannelOpen = false
        }

        if !controlChannelOpen || !interruptChannelOpen {
            handleDisconnection()
        }
    }

    private var isReconnecting = false

    private func handleDisconnection() {
        guard !isReconnecting else { return }
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
