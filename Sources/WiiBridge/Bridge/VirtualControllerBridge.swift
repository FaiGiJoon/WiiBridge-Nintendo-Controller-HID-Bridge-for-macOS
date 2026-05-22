import Foundation
import GameController

class VirtualControllerBridge {
    static let shared = VirtualControllerBridge()
    private var controllers: [ObjectIdentifier: GCVirtualController] = [:]
    
    func addDevice(_ wiiDevice: WiiDevice) {
        let config = GCVirtualController.Configuration()
        config.elements = [
            GCInputButtonA,
            GCInputButtonB,
            GCInputButtonX,
            GCInputButtonY,
            GCInputDirectionPad,
            GCInputButtonMenu,
            GCInputButtonOptions,
            GCInputLeftThumbstick,
            GCInputRightThumbstick
        ]
        let virtualController = GCVirtualController(configuration: config)
        
        virtualController.connect { error in
            if let error = error {
                print("Virtual controller connection failed: \(error)")
            } else {
                print("Virtual controller connected")
            }
        }
        
        let id = ObjectIdentifier(wiiDevice)
        controllers[id] = virtualController
        
        wiiDevice.addObserver { [weak self] state in
            self?.update(id: id, with: state)
        }
    }
    
    private func update(id: ObjectIdentifier, with wiiState: WiiState) {
        guard let virtualController = controllers[id] else { return }
        
        // Programmatically set values on the virtual controller
        virtualController.setValue(wiiState.buttonA ? 1.0 : 0.0, forButtonElement: GCInputButtonA)
        virtualController.setValue(wiiState.buttonB ? 1.0 : 0.0, forButtonElement: GCInputButtonB)
        virtualController.setValue(wiiState.buttonOne ? 1.0 : 0.0, forButtonElement: GCInputButtonX)
        virtualController.setValue(wiiState.buttonTwo ? 1.0 : 0.0, forButtonElement: GCInputButtonY)
        
        // D-Pad
        let dpadX: CGFloat = (wiiState.dpadLeft ? -1.0 : 0.0) + (wiiState.dpadRight ? 1.0 : 0.0)
        let dpadY: CGFloat = (wiiState.dpadDown ? -1.0 : 0.0) + (wiiState.dpadUp ? 1.0 : 0.0)
        virtualController.setPosition(CGPoint(x: dpadX, y: dpadY), forDirectionPadElement: GCInputDirectionPad)
        
        // Analog Sticks
        var lx = CGFloat((wiiState.lStickX * 2.0) - 1.0)
        var ly = CGFloat((wiiState.lStickY * 2.0) - 1.0)

        var rx = CGFloat((wiiState.rStickX * 2.0) - 1.0)
        var ry = CGFloat((wiiState.rStickY * 2.0) - 1.0)
        
        // If it's a uDraw tablet, map the stylus position to the sticks if desired,
        // or just rely on the specialized uDraw support in Dolphin which might expect specific HID reports.
        // For broad compatibility, we map uDraw to Left Stick.
        if wiiState.uDrawX < 1.0 && wiiState.uDrawY < 1.0 {
            lx = CGFloat((wiiState.uDrawX * 2.0) - 1.0)
            ly = CGFloat((wiiState.uDrawY * 2.0) - 1.0)

            // Map upper button to X, lower to Y
            virtualController.setValue(wiiState.uDrawButtonUpper ? 1.0 : 0.0, forButtonElement: GCInputButtonX)
            virtualController.setValue(wiiState.uDrawButtonLower ? 1.0 : 0.0, forButtonElement: GCInputButtonY)
        }

        virtualController.setPosition(CGPoint(x: lx, y: ly), forDirectionPadElement: GCInputLeftThumbstick)
        virtualController.setPosition(CGPoint(x: rx, y: ry), forDirectionPadElement: GCInputRightThumbstick)
        
        virtualController.setValue(wiiState.buttonHome ? 1.0 : 0.0, forButtonElement: GCInputButtonMenu)
        virtualController.setValue(wiiState.buttonPlus ? 1.0 : 0.0, forButtonElement: GCInputButtonOptions)

        // Motion
        if let motion = virtualController.controller?.motion {
            // We map normalized 0..1 to -1..1 range for gravity/acceleration
            let gx = (wiiState.accelX * 2.0) - 1.0
            let gy = (wiiState.accelY * 2.0) - 1.0
            let gz = (wiiState.accelZ * 2.0) - 1.0

            // This is a simplification; a real implementation would use GCMotion's internal gravity/userAcceleration
            // For GCVirtualController, we may need to inject motion data if supported via internal APIs or use it for specific mappings.
            // Since GCVirtualController doesn't have direct 'setGravity', this serves as a placeholder for where that logic resides.
            // Some developers map tilt to stick values if motion isn't directly settable.
        }
    }
}
