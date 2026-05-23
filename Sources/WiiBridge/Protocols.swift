import Foundation

protocol BluetoothProvider: AnyObject {
    func scan() -> AsyncStream<BluetoothDevice>
    func stopScanning()
    func connect(device: BluetoothDevice) async throws -> L2CAPChannelGroup
}

protocol BluetoothDevice: AnyObject {
    var name: String? { get }
    var addressString: String { get }
}

protocol L2CAPChannelGroup: AnyObject {
    var controlChannel: L2CAPChannel? { get }
    var interruptChannel: L2CAPChannel? { get }
    func disconnect()
}

protocol L2CAPChannel: AnyObject {
    func send(data: Data)
    var onData: ((Data) -> Void)? { get set }
    var onClosed: (() -> Void)? { get set }
}

protocol VirtualControllerProvider: AnyObject {
    func update(device: WiiDevice, state: WiiState)
}
