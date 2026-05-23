import Foundation
#if os(Linux)
import Glibc

class LinuxVirtualControllerProvider: VirtualControllerProvider {
    private var fd: Int32 = -1

    struct input_event {
        var time: timeval
        var type: UInt16
        var code: UInt16
        var value: Int32
    }

    private let UI_SET_EVBIT: UInt = 0x40045564
    private let UI_SET_KEYBIT: UInt = 0x40045565
    private let UI_SET_ABSBIT: UInt = 0x40045566
    private let UI_DEV_SETUP: UInt = 0x405c5503
    private let UI_DEV_CREATE: UInt = 0x5501

    private let EV_KEY: UInt16 = 0x01
    private let EV_ABS: UInt16 = 0x03
    private let EV_SYN: UInt16 = 0x00
    private let SYN_REPORT: UInt16 = 0x00

    // Key codes from linux/input-event-codes.h
    private let BTN_SOUTH: UInt16 = 0x130 // A
    private let BTN_EAST: UInt16 = 0x131  // B
    private let BTN_NORTH: UInt16 = 0x133 // X (1)
    private let BTN_WEST: UInt16 = 0x134  // Y (2)
    private let BTN_SELECT: UInt16 = 0x13a // Minus
    private let BTN_START: UInt16 = 0x13b  // Plus
    private let BTN_MODE: UInt16 = 0x13c   // Home

    private let ABS_X: UInt16 = 0x00
    private let ABS_Y: UInt16 = 0x01
    private let ABS_HAT0X: UInt16 = 0x10
    private let ABS_HAT0Y: UInt16 = 0x11

    init() {
        fd = open("/dev/uinput", O_WRONLY | O_NONBLOCK)
        guard fd >= 0 else { return }

        ioctl(fd, UI_SET_EVBIT, UInt(EV_KEY))
        [BTN_SOUTH, BTN_EAST, BTN_NORTH, BTN_WEST, BTN_SELECT, BTN_START, BTN_MODE].forEach {
            ioctl(fd, UI_SET_KEYBIT, UInt($0))
        }

        ioctl(fd, UI_SET_EVBIT, UInt(EV_ABS))
        [ABS_X, ABS_Y, ABS_HAT0X, ABS_HAT0Y].forEach {
            ioctl(fd, UI_SET_ABSBIT, UInt($0))
        }

        ioctl(fd, UI_DEV_CREATE)
        print("Linux: Virtual Gamepad 'WiiBridge' initialized.")
    }

    func update(device: WiiDevice, state: WiiState) {
        guard fd >= 0 else { return }

        sendEvent(type: EV_KEY, code: BTN_SOUTH, value: state.buttonA ? 1 : 0)
        sendEvent(type: EV_KEY, code: BTN_EAST, value: state.buttonB ? 1 : 0)
        sendEvent(type: EV_KEY, code: BTN_NORTH, value: state.buttonOne ? 1 : 0)
        sendEvent(type: EV_KEY, code: BTN_WEST, value: state.buttonTwo ? 1 : 0)
        sendEvent(type: EV_KEY, code: BTN_SELECT, value: state.buttonMinus ? 1 : 0)
        sendEvent(type: EV_KEY, code: BTN_START, value: state.buttonPlus ? 1 : 0)
        sendEvent(type: EV_KEY, code: BTN_MODE, value: state.buttonHome ? 1 : 0)

        sendEvent(type: EV_ABS, code: ABS_HAT0X, value: state.dpadLeft ? -1 : (state.dpadRight ? 1 : 0))
        sendEvent(type: EV_ABS, code: ABS_HAT0Y, value: state.dpadUp ? -1 : (state.dpadDown ? 1 : 0))

        sendEvent(type: EV_ABS, code: ABS_X, value: Int32(state.lStickX * 255.0))
        sendEvent(type: EV_ABS, code: ABS_Y, value: Int32(state.lStickY * 255.0))

        sendEvent(type: EV_SYN, code: SYN_REPORT, value: 0)
    }

    private func sendEvent(type: UInt16, code: UInt16, value: Int32) {
        var ev = input_event(time: timeval(), type: type, code: code, value: value)
        write(fd, &ev, MemoryLayout<input_event>.size)
    }

    deinit {
        if fd >= 0 { Glibc.close(fd) }
    }
}
#endif
