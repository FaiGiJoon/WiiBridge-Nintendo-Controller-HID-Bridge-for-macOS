import Foundation
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
            GCInputLeftShoulder,
            GCInputRightShoulder,
            GCInputLeftTrigger,
            GCInputRightTrigger,
            GCInputLeftThumbstickButton,
            GCInputRightThumbstickButton
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
        
        let dolphinOptimized = UserDefaults.standard.bool(forKey: "dolphinOptimized")
        let emulateUDraw = UserDefaults.standard.bool(forKey: "emulateUDraw")

        virtualController.setValue(state.buttonA ? 1.0 : 0.0, forButtonElement: GCInputButtonA)
        virtualController.setValue(state.buttonB ? 1.0 : 0.0, forButtonElement: GCInputButtonB)
        
        if device.type == .wiiRemote || device.type == .nunchuk {
            virtualController.setValue(state.buttonOne ? 1.0 : 0.0, forButtonElement: GCInputButtonX)
            virtualController.setValue(state.buttonTwo ? 1.0 : 0.0, forButtonElement: GCInputButtonY)
        } else {
            virtualController.setValue(state.buttonX ? 1.0 : 0.0, forButtonElement: GCInputButtonX)
            virtualController.setValue(state.buttonY ? 1.0 : 0.0, forButtonElement: GCInputButtonY)
        }

        virtualController.setValue(state.buttonL ? 1.0 : 0.0, forButtonElement: GCInputLeftShoulder)
        virtualController.setValue(state.buttonR ? 1.0 : 0.0, forButtonElement: GCInputRightShoulder)
        virtualController.setValue(state.buttonZL ? 1.0 : 0.0, forButtonElement: GCInputLeftTrigger)
        virtualController.setValue(state.buttonZR ? 1.0 : 0.0, forButtonElement: GCInputRightTrigger)

        if device.type == .nunchuk {
            virtualController.setValue(state.buttonZ ? 1.0 : 0.0, forButtonElement: GCInputLeftTrigger)
            virtualController.setValue(state.buttonC ? 1.0 : 0.0, forButtonElement: GCInputLeftShoulder)
        }

        virtualController.setValue(state.lThumbClick ? 1.0 : 0.0, forButtonElement: GCInputLeftThumbstickButton)
        virtualController.setValue(state.rThumbClick ? 1.0 : 0.0, forButtonElement: GCInputRightThumbstickButton)

        let dpadX: CGFloat = (state.dpadLeft ? -1.0 : 0.0) + (state.dpadRight ? 1.0 : 0.0)
        let dpadY: CGFloat = (state.dpadDown ? -1.0 : 0.0) + (state.dpadUp ? 1.0 : 0.0)
        virtualController.setPosition(CGPoint(x: dpadX, y: dpadY), forDirectionPadElement: GCInputDirectionPad)
        
        func applyDeadzone(_ val: Double) -> CGFloat {
            let centered = (val * 2.0) - 1.0
            if dolphinOptimized && abs(centered) < 0.05 { return 0.0 }
            return CGFloat(centered)
        }

        var lx = applyDeadzone(state.lStickX)
        var ly = applyDeadzone(state.lStickY)
        var rx = applyDeadzone(state.rStickX)
        var ry = applyDeadzone(state.rStickY)
        
        if emulateUDraw && state.uDrawX < 1.0 && state.uDrawY < 1.0 {
            lx = CGFloat((state.uDrawX * 2.0) - 1.0)
            ly = CGFloat((state.uDrawY * 2.0) - 1.0)
            virtualController.setValue(state.uDrawButtonUpper ? 1.0 : 0.0, forButtonElement: GCInputButtonX)
            virtualController.setValue(state.uDrawButtonLower ? 1.0 : 0.0, forButtonElement: GCInputButtonY)
        }

        virtualController.setPosition(CGPoint(x: lx, y: ly), forDirectionPadElement: GCInputLeftThumbstick)
        virtualController.setPosition(CGPoint(x: rx, y: ry), forDirectionPadElement: GCInputRightThumbstick)
        
        virtualController.setValue(state.buttonHome ? 1.0 : 0.0, forButtonElement: GCInputButtonMenu)
        virtualController.setValue(state.buttonPlus ? 1.0 : 0.0, forButtonElement: GCInputButtonOptions)
    }
}
