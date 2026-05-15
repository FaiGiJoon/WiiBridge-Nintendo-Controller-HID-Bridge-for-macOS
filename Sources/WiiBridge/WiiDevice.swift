import Foundation

struct WiiState {
    var buttonA = false
    var buttonB = false
    var buttonOne = false
    var buttonTwo = false
    var buttonMinus = false
    var buttonPlus = false
    var buttonHome = false
    var dpadUp = false
    var dpadDown = false
    var dpadLeft = false
    var dpadRight = false
    
    var lStickX: Double = 0.5
    var lStickY: Double = 0.5
    var rStickX: Double = 0.5
    var rStickY: Double = 0.5
    
    var hasExtension = false
}

class WiiDevice {
    weak var connection: WiiConnection?
    var state = WiiState()
    var onUpdate: ((WiiState) -> Void)?
    
    enum ControllerType {
        case wiiRemote
        case wiiUPro
        case nunchuk
    }
    var type: ControllerType = .wiiRemote
    
    func initialize() {
        // 1. Initialize extension (Wii U Pro / Nunchuk)
        // Write 0x55 to 0x04A40040
        writeRegister(address: 0x04A40040, data: Data([0x55]))
        // Write 0x00 to 0x04A400FB
        writeRegister(address: 0x04A400FB, data: Data([0x00]))
        
        // 2. Set reporting mode to include extension data (0x34)
        connection?.send(data: Data([0x12, 0x00, 0x34]))
        
        // 3. Set LED 1
        connection?.send(data: Data([0x11, 0x10]))
    }
    
    private func writeRegister(address: UInt32, data: Data) {
        var report = Data([0x16]) // Write Register Report
        let addrBytes = withUnsafeBytes(of: address.bigEndian) { Data($0) }
        report.append(addrBytes.subdata(in: 1..<4)) // 3-byte address
        report.append(UInt8(data.count))
        report.append(data)
        // Pad to 16 bytes payload (Report 0x16 is 22 bytes total including ID)
        while report.count < 22 {
            report.append(0x00)
        }
        connection?.send(data: report)
    }
    
    func parse(data: Data) {
        guard data.count >= 3 else { return }
        let reportId = data[0]
        
        // Buttons (Bytes 1 and 2 are same for most reports)
        let b1 = data[1]
        let b2 = data[2]
        
        state.dpadLeft = (b1 & 0x01) != 0
        state.dpadRight = (b1 & 0x02) != 0
        state.dpadDown = (b1 & 0x04) != 0
        state.dpadUp = (b1 & 0x08) != 0
        state.buttonPlus = (b1 & 0x10) != 0
        
        state.buttonTwo = (b2 & 0x01) != 0
        state.buttonOne = (b2 & 0x02) != 0
        state.buttonB = (b2 & 0x04) != 0
        state.buttonA = (b2 & 0x08) != 0
        state.buttonMinus = (b2 & 0x10) != 0
        state.buttonHome = (b2 & 0x80) != 0
        
        if reportId == 0x34 && data.count >= 22 {
            let ext = data.subdata(in: 3..<22)
            // Identify extension by size/handshake or simple check
            // Wii U Pro has a specific signature, but for now we'll do basic stick parsing
            if ext.count >= 10 {
                // Wii U Pro parsing (Stick values are often 12-bit, but simpler 8-bit here for skeleton)
                state.lStickX = Double(ext[0]) / 255.0
                state.lStickY = Double(ext[1]) / 255.0
                state.rStickX = Double(ext[2]) / 255.0
                state.rStickY = Double(ext[3]) / 255.0
                state.hasExtension = true
            }
        }
        
        DispatchQueue.main.async {
            self.onUpdate?(self.state)
        }
    }
}
