import Foundation
import IOKit.hid

class VirtualHIDBridge {
    static let shared = VirtualHIDBridge()
    private var devices: [ObjectIdentifier: IOHIDUserDevice] = [:]
    
    // Standard Gamepad HID Report Descriptor
    private let reportDescriptor: [UInt8] = [
        0x05, 0x01,        // Usage Page (Generic Desktop Ctrls)
        0x09, 0x05,        // Usage (Game Pad)
        0xA1, 0x01,        // Collection (Application)
        0x85, 0x01,        //   Report ID (1)
        0x05, 0x09,        //   Usage Page (Button)
        0x19, 0x01,        //   Usage Minimum (0x01)
        0x29, 0x10,        //   Usage Maximum (0x10)
        0x15, 0x00,        //   Logical Minimum (0)
        0x25, 0x01,        //   Logical Maximum (1)
        0x75, 0x01,        //   Report Size (1)
        0x95, 0x10,        //   Report Count (16)
        0x81, 0x02,        //   Input (Data,Var,Abs,No Wrap,Linear,Preferred State,No Null Position)
        0x05, 0x01,        //   Usage Page (Generic Desktop Ctrls)
        0x09, 0x30,        //   Usage (X)
        0x09, 0x31,        //   Usage (Y)
        0x09, 0x32,        //   Usage (Z)
        0x09, 0x35,        //   Usage (Rz)
        0x15, 0x00,        //   Logical Minimum (0)
        0x26, 0xFF, 0x00,  //   Logical Maximum (255)
        0x75, 0x08,        //   Report Size (8)
        0x95, 0x04,        //   Report Count (4)
        0x81, 0x02,        //   Input (Data,Var,Abs,No Wrap,Linear,Preferred State,No Null Position)
        0xC0               // End Collection
    ]
    
    func addDevice(_ wiiDevice: WiiDevice) {
        let descriptorData = Data(reportDescriptor)
        let properties: [String: Any] = [
            kIOHIDVendorIDKey: 0x057E, // Nintendo
            kIOHIDProductIDKey: 0x0306, // Wii Remote
            kIOHIDReportDescriptorKey: descriptorData
        ]
        
        guard let userDevice = IOHIDUserDeviceCreate(kCFAllocatorDefault, descriptorData as CFData, properties as CFDictionary) else {
            return
        }
        
        let id = ObjectIdentifier(wiiDevice)
        devices[id] = userDevice
        
        wiiDevice.addObserver { [weak self] state in
            self?.sendUpdate(id: id, state: state)
        }
    }
    
    private func sendUpdate(id: ObjectIdentifier, state: WiiState) {
        guard let userDevice = devices[id] else { return }
        
        var report = [UInt8](repeating: 0, count: 7)
        report[0] = 0x01 // Report ID
        
        // Buttons (Byte 1 & 2)
        var buttons: UInt16 = 0
        if state.buttonA { buttons |= 1 << 0 }
        if state.buttonB { buttons |= 1 << 1 }
        if state.buttonOne { buttons |= 1 << 2 }
        if state.buttonTwo { buttons |= 1 << 3 }
        if state.buttonMinus { buttons |= 1 << 4 }
        if state.buttonPlus { buttons |= 1 << 5 }
        if state.buttonHome { buttons |= 1 << 6 }
        if state.dpadUp { buttons |= 1 << 7 }
        if state.dpadDown { buttons |= 1 << 8 }
        if state.dpadLeft { buttons |= 1 << 9 }
        if state.dpadRight { buttons |= 1 << 10 }
        
        report[1] = UInt8(buttons & 0xFF)
        report[2] = UInt8((buttons >> 8) & 0xFF)
        
        // Sticks (Byte 3-6)
        report[3] = UInt8(state.lStickX * 255.0)
        report[4] = UInt8(state.lStickY * 255.0)
        report[5] = UInt8(state.rStickX * 255.0)
        report[6] = UInt8(state.rStickY * 255.0)
        
        IOHIDUserDevicePostReport(userDevice, report, report.count)
    }
}
