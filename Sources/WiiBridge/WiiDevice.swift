import Foundation

struct WiiState {
    var buttonA = false
    var buttonB = false
    var buttonOne = false
    var buttonTwo = false
    var buttonMinus = false
    var buttonPlus = false
    var buttonHome = false
    var buttonX = false
    var buttonY = false
    var buttonL = false
    var buttonR = false
    var buttonZL = false
    var buttonZR = false
    var buttonC = false
    var buttonZ = false
    var lThumbClick = false
    var rThumbClick = false
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

    // uDraw specific
    var uDrawX: Double = 1.0 // Normalized 0..1, 1.0 means stylus away
    var uDrawY: Double = 1.0
    var uDrawPressure: Double = 0.0
    var uDrawButtonLower = false
    var uDrawButtonUpper = false

    var batteryLevel: Double = 0.0
    var isRumbling = false
}

@MainActor
class WiiDevice {
    weak var connection: WiiConnection?
    var state = WiiState()
    private var observers: [(WiiState) -> Void] = []
    var virtualController: VirtualControllerProvider?

    func addObserver(_ observer: @escaping (WiiState) -> Void) {
        observers.append(observer)
        observer(state)
    }
    
    enum ControllerType {
        case wiiRemote
        case wiiUPro
        case nunchuk
        case classicController
        case uDraw
    }
    var type: ControllerType = .wiiRemote
    
    func initialize() {
        writeRegister(address: 0x04A400F0, data: Data([0x55]))
        writeRegister(address: 0x04A400FB, data: Data([0x00]))
        setReportingMode(0x35)
        setLED(1)
        requestStatus()
        readRegister(address: 0x04A400FA, length: 6) { [weak self] data in
            self?.identifyExtension(data: data)
        }
    }

    private func identifyExtension(data: Data) {
        guard data.count >= 6 else { return }
        if data[0] == 0xFF && data[1] == 0x00 && data[4] == 0x01 && data[5] == 0x12 {
            self.type = .uDraw
        } else if data[4] == 0x00 && data[5] == 0x00 {
            self.type = .nunchuk
        } else if data[4] == 0x01 && data[5] == 0x01 {
            self.type = .classicController
        } else if data[4] == 0x01 && data[5] == 0x20 {
            self.type = .wiiUPro
        }
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
        setLED(1)
    }

    func requestStatus() {
        var data = Data([0x15, 0x00])
        if state.isRumbling { data[1] |= 0x01 }
        connection?.send(data: data)
    }
    
    private var pendingReadCallbacks: [UInt32: (Data) -> Void] = [:]

    private func writeRegister(address: UInt32, data: Data) {
        var report = Data([0x16])
        let addrBytes = withUnsafeBytes(of: address.bigEndian) { Data($0) }
        report.append(addrBytes.subdata(in: 1..<4))
        report.append(UInt8(data.count))
        report.append(data)
        while report.count < 22 { report.append(0x00) }
        connection?.send(data: report)
    }

    private func readRegister(address: UInt32, length: UInt8, completion: @escaping (Data) -> Void) {
        pendingReadCallbacks[address & 0xFFFF] = completion
        var report = Data([0x17])
        let addrBytes = withUnsafeBytes(of: address.bigEndian) { Data($0) }
        report.append(addrBytes.subdata(in: 1..<4))
        let lenHigh = UInt8((length >> 8) & 0xFF)
        let lenLow = UInt8(length & 0xFF)
        report.append(lenHigh)
        report.append(lenLow)
        connection?.send(data: report)
    }
    
    func parse(data: Data) {
        guard data.count >= 3 else { return }
        let reportId = data[0]
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
            let batteryRaw = data[6]
            state.batteryLevel = Double(batteryRaw) / 200.0
            state.hasExtension = (data[3] & 0x02) != 0
        } else if reportId == 0x21 && data.count >= 21 {
            let address = (UInt32(data[4]) << 8) | UInt32(data[5])
            let payload = data.subdata(in: 6..<data.count)
            if let callback = pendingReadCallbacks.removeValue(forKey: address) {
                callback(payload)
            }
        } else if reportId == 0x35 && data.count >= 21 {
            state.accelX = Double(data[3]) / 255.0
            state.accelY = Double(data[4]) / 255.0
            state.accelZ = Double(data[5]) / 255.0
            let ext = data.subdata(in: 6..<min(data.count, 21))
            parseExtension(ext)
        }
        
        virtualController?.update(device: self, state: state)
        for observer in self.observers {
            observer(self.state)
        }
    }

    private func parseExtension(_ data: Data) {
        guard data.count >= 6 else { return }
        state.hasExtension = true
        switch type {
        case .uDraw:
            let xRaw = UInt16(data[0]) | (UInt16(data[2] & 0x0F) << 8)
            let yRaw = UInt16(data[1]) | (UInt16(data[2] & 0xF0) << 4)
            let pRaw = UInt16(data[3]) | (UInt16(data[5] & 0x04) << 6)
            state.uDrawX = Double(xRaw) / 4095.0
            state.uDrawY = Double(yRaw) / 4095.0
            state.uDrawPressure = Double(pRaw) / 511.0
            state.uDrawButtonLower = (data[5] & 0x02) == 0
            state.uDrawButtonUpper = (data[5] & 0x01) == 0
        case .nunchuk:
            state.lStickX = Double(data[0]) / 255.0
            state.lStickY = Double(data[1]) / 255.0
            state.buttonZ = (data[5] & 0x01) == 0
            state.buttonC = (data[5] & 0x02) == 0
        case .classicController:
            state.lStickX = Double(data[0] & 0x3F) / 63.0
            state.lStickY = Double(data[1] & 0x3F) / 63.0
            state.rStickX = Double(((data[0] & 0xC0) >> 3) | ((data[1] & 0xC0) >> 5) | ((data[2] & 0x80) >> 7)) / 31.0
            state.rStickY = Double(data[2] & 0x1F) / 31.0

            let b1 = data[4]
            let b2 = data[5]

            state.buttonR = (b1 & 0x02) == 0
            state.buttonPlus = (b1 & 0x04) == 0
            state.buttonHome = (b1 & 0x08) == 0
            state.buttonMinus = (b1 & 0x10) == 0
            state.buttonL = (b1 & 0x20) == 0
            state.dpadDown = (b1 & 0x40) == 0
            state.dpadRight = (b1 & 0x80) == 0

            state.buttonZR = (b2 & 0x02) == 0
            state.buttonX = (b2 & 0x08) == 0
            state.buttonA = (b2 & 0x10) == 0
            state.buttonY = (b2 & 0x20) == 0
            state.buttonB = (b2 & 0x40) == 0
            state.buttonZL = (b2 & 0x80) == 0
        case .wiiUPro:
            // Wii U Pro has 12-bit sticks and buttons in inverted bits
            // Format: LX (2 bytes), LY (2 bytes), RX (2 bytes), RY (2 bytes), Buttons (3 bytes)
            if data.count >= 11 {
                let lx = UInt16(data[0]) | (UInt16(data[1]) << 8)
                let ly = UInt16(data[2]) | (UInt16(data[3]) << 8)
                let rx = UInt16(data[4]) | (UInt16(data[5]) << 8)
                let ry = UInt16(data[6]) | (UInt16(data[7]) << 8)
                state.lStickX = Double(lx) / 4095.0
                state.lStickY = Double(ly) / 4095.0
                state.rStickX = Double(rx) / 4095.0
                state.rStickY = Double(ry) / 4095.0

                let b1 = data[8]
                let b2 = data[9]
                let b3 = data[10]

                state.buttonR = (b1 & 0x02) == 0
                state.buttonPlus = (b1 & 0x04) == 0
                state.buttonHome = (b1 & 0x08) == 0
                state.buttonMinus = (b1 & 0x10) == 0
                state.buttonL = (b1 & 0x20) == 0
                state.dpadDown = (b1 & 0x40) == 0
                state.dpadRight = (b1 & 0x80) == 0

                state.buttonZR = (b2 & 0x02) == 0
                state.buttonX = (b2 & 0x08) == 0
                state.buttonA = (b2 & 0x10) == 0
                state.buttonY = (b2 & 0x20) == 0
                state.buttonB = (b2 & 0x40) == 0
                state.buttonZL = (b2 & 0x80) == 0

                state.lThumbClick = (b3 & 0x02) == 0
                state.rThumbClick = (b3 & 0x01) == 0
                state.dpadUp = (b2 & 0x01) == 0
                state.dpadLeft = (b1 & 0x01) == 0
            }
        case .wiiRemote:
            break
        }
    }
}
