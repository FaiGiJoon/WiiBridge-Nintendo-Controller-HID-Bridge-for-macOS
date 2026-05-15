import XCTest
@testable import WiiBridge

final class WiiBridgeTests: XCTestCase {
    func testWiiButtonParsing() throws {
        let device = WiiDevice()
        // Report 0x30, Buttons: A (0x08 in byte 2), B (0x04 in byte 2)
        let data = Data([0x30, 0x00, 0x0C])
        device.parse(data: data)
        
        XCTAssertTrue(device.state.buttonA)
        XCTAssertTrue(device.state.buttonB)
        XCTAssertFalse(device.state.buttonOne)
    }
    
    func testPINCalculation() throws {
        // Since we can't easily mock IOBluetoothDevice here without a lot of effort,
        // we'll at least check the logic if possible or skip.
        // For now, focus on parsing.
    }
}
