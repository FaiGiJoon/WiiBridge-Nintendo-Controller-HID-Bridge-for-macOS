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
    
    var accelX: Double = 0.0
    var accelY: Double = 0.0
    var accelZ: Double = 0.0

    var hasExtension = false

    var batteryLevel: Double = 0.0
    var isRumbling = false
}

class WiiDevice {
    weak var connection: WiiConnection?
    var state = WiiState()
    private var observers: [(WiiState) -> Void] = []

    func addObserver(_ observer: @escaping (WiiState) -> Void) {
        observers.append(observer)
        observer(state)
    }
    
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
        
        // 2. Set reporting mode to include extension data and accelerometer (0x35)
        // 0x35: Core Buttons + Accelerometer + 16 Extension Bytes
        setReportingMode(0x35)
        
        // 3. Set LED 1
        setLED(1)

        // 4. Request status to get initial battery level
        requestStatus()
    }

    func setReportingMode(_ mode: UInt8) {
        var data = Data([0x12, 0x00, mode])
        if state.isRumbling { data[1] |= 0x01 }
        connection?.send(data: data)
    }

    func setLED(_ led: Int) {
        var val: UInt8 = 0
        if led == 1 { val = 0x10 }
        else if led == 2 { val = 0x20 }
        else if led == 3 { val = 0x40 }
        else if led == 4 { val = 0x80 }

        var data = Data([0x11, val])
        if state.isRumbling { data[1] |= 0x01 }
        connection?.send(data: data)
    }

    func setRumble(_ on: Bool) {
        state.isRumbling = on
        // Send a Player LED report with the Rumble bit set/unset
        // We need to keep the current LED state, but for simplicity we'll just send LED 1
        setLED(1)
    }

    func requestStatus() {
        var data = Data([0x15, 0x00])
        if state.isRumbling { data[1] |= 0x01 }
        connection?.send(data: data)
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
        // Bounds checking to prevent buffer overflows
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
        
        if reportId == 0x20 && data.count >= 7 {
            // Status report
            let batteryRaw = data[6]
            state.batteryLevel = Double(batteryRaw) / 200.0 // 0xC8 (200) is max
            state.hasExtension = (data[3] & 0x02) != 0
        } else if reportId == 0x35 && data.count >= 21 {
            // 0x35: BB AA EE EE EE EE EE EE EE EE EE EE EE EE EE EE EE EE
            // AA are accel bytes
            let a1 = data[3]
            let a2 = data[4]
            let a3 = data[5]

            // Accel data is 10-bit.
            // X: bits 2-9 of byte 3, bits 1-2 of byte 1 (LSB)
            // Y: bits 2-9 of byte 4, bit 5 of byte 2 (LSB)
            // Z: bits 2-9 of byte 5, bit 6 of byte 2 (LSB)
            // For simplicity, we use the 8-bit MSB here.
            state.accelX = Double(a1) / 255.0
            state.accelY = Double(a2) / 255.0
            state.accelZ = Double(a3) / 255.0

            let ext = data.subdata(in: 6..<min(data.count, 21))
            if ext.count >= 10 {
                state.lStickX = Double(ext[0]) / 255.0
                state.lStickY = Double(ext[1]) / 255.0
                state.rStickX = Double(ext[2]) / 255.0
                state.rStickY = Double(ext[3]) / 255.0
                state.hasExtension = true
            }
        }
        
        DispatchQueue.main.async {
            for observer in self.observers {
                observer(self.state)
            }
        }
    }
}
