import Foundation
#if os(macOS)
import GameController

class VirtualControllerBridge: VirtualControllerProvider {
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
            GCInputRightThumbstick,
            GCInputLeftTrigger,
            GCInputRightTrigger
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
        wiiDevice.virtualController = self
    }
    
    func update(device: WiiDevice, state: WiiState) {
        let id = ObjectIdentifier(device)
        guard let virtualController = controllers[id] else { return }
        
        virtualController.setValue(state.buttonA ? 1.0 : 0.0, forButtonElement: GCInputButtonA)
        virtualController.setValue(state.buttonB ? 1.0 : 0.0, forButtonElement: GCInputButtonB)
        virtualController.setValue(state.buttonOne ? 1.0 : 0.0, forButtonElement: GCInputButtonX)
        virtualController.setValue(state.buttonTwo ? 1.0 : 0.0, forButtonElement: GCInputButtonY)
        
        let dpadX: CGFloat = (state.dpadLeft ? -1.0 : 0.0) + (state.dpadRight ? 1.0 : 0.0)
        let dpadY: CGFloat = (state.dpadDown ? -1.0 : 0.0) + (state.dpadUp ? 1.0 : 0.0)
        virtualController.setPosition(CGPoint(x: dpadX, y: dpadY), forDirectionPadElement: GCInputDirectionPad)
        
        var lx = CGFloat((state.lStickX * 2.0) - 1.0)
        var ly = CGFloat((state.lStickY * 2.0) - 1.0)
        var rx = CGFloat((state.rStickX * 2.0) - 1.0)
        var ry = CGFloat((state.rStickY * 2.0) - 1.0)
        
        if device.type == .uDraw && state.uDrawX < 1.0 && state.uDrawY < 1.0 {
            lx = CGFloat((state.uDrawX * 2.0) - 1.0)
            ly = CGFloat((state.uDrawY * 2.0) - 1.0)
            virtualController.setValue(state.uDrawButtonUpper ? 1.0 : 0.0, forButtonElement: GCInputButtonX)
            virtualController.setValue(state.uDrawButtonLower ? 1.0 : 0.0, forButtonElement: GCInputButtonY)
        } else if device.type == .nunchuk {
            virtualController.setValue(state.nunchukButtonC ? 1.0 : 0.0, forButtonElement: GCInputLeftTrigger)
            virtualController.setValue(state.nunchukButtonZ ? 1.0 : 0.0, forButtonElement: GCInputRightTrigger)
        }

        virtualController.setPosition(CGPoint(x: lx, y: ly), forDirectionPadElement: GCInputLeftThumbstick)
        virtualController.setPosition(CGPoint(x: rx, y: ry), forDirectionPadElement: GCInputRightThumbstick)
        
        virtualController.setValue(state.buttonHome ? 1.0 : 0.0, forButtonElement: GCInputButtonMenu)
        virtualController.setValue(state.buttonPlus ? 1.0 : 0.0, forButtonElement: GCInputButtonOptions)
    }
}
#endif
