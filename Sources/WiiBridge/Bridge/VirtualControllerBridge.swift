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
        let lx = CGFloat((wiiState.lStickX * 2.0) - 1.0)
        let ly = CGFloat((wiiState.lStickY * 2.0) - 1.0)
        virtualController.setPosition(CGPoint(x: lx, y: ly), forDirectionPadElement: GCInputLeftThumbstick)
        
        let rx = CGFloat((wiiState.rStickX * 2.0) - 1.0)
        let ry = CGFloat((wiiState.rStickY * 2.0) - 1.0)
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
