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

    struct uinput_setup {
        var id: input_id
        var name: (Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8)
        var ff_effects_max: UInt32
    }

    struct input_id {
        var bustype: UInt16
        var vendor: UInt16
        var product: UInt16
        var version: UInt16
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

    private let BTN_SOUTH: UInt16 = 0x130
    private let BTN_EAST: UInt16 = 0x131
    private let BTN_NORTH: UInt16 = 0x133
    private let BTN_WEST: UInt16 = 0x134

    private let ABS_X: UInt16 = 0x00
    private let ABS_Y: UInt16 = 0x01
    private let ABS_HAT0X: UInt16 = 0x10
    private let ABS_HAT0Y: UInt16 = 0x11

    init() {
        fd = open("/dev/uinput", O_WRONLY | O_NONBLOCK)
        guard fd >= 0 else { return }

        ioctl(fd, UI_SET_EVBIT, UInt(EV_KEY))
        [BTN_SOUTH, BTN_EAST, BTN_NORTH, BTN_WEST].forEach { ioctl(fd, UI_SET_KEYBIT, UInt($0)) }

        ioctl(fd, UI_SET_EVBIT, UInt(EV_ABS))
        [ABS_X, ABS_Y, ABS_HAT0X, ABS_HAT0Y].forEach { ioctl(fd, UI_SET_ABSBIT, UInt($0)) }

        var setup = uinput_setup(id: input_id(bustype: 0x03, vendor: 0x057e, product: 0x0306, version: 1), name: (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0), ff_effects_max: 0)
        "WiiBridge Virtual Controller".withCString { ptr in
            let namePtr = withUnsafeMutablePointer(to: &setup.name) { UnsafeMutableRawPointer($0).assumingMemoryBound(to: Int8.self) }
            _ = strncpy(namePtr, ptr, 80)
        }

        ioctl(fd, UI_DEV_SETUP, &setup)
        ioctl(fd, UI_DEV_CREATE)
        print("Linux: Virtual Gamepad 'WiiBridge' initialized.")
    }

    func update(device: WiiDevice, state: WiiState) {
        guard fd >= 0 else { return }

        sendEvent(type: EV_KEY, code: BTN_SOUTH, value: state.buttonA ? 1 : 0)
        sendEvent(type: EV_KEY, code: BTN_EAST, value: state.buttonB ? 1 : 0)

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
