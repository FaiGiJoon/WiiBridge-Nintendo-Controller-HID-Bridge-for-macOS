# WiiBridge

WiiBridge is a macOS Swift application that bridges Nintendo Wii and Wii U Pro controllers to the Apple GameController framework using `GCVirtualController`. It is designed for modern macOS (14+) and Apple Silicon hardware.

## How it Works

WiiBridge connects to Nintendo controllers via Bluetooth L2CAP channels (PSM 0x11 for Control and 0x13 for Interrupt). It parses the HID reports sent by the controllers and translates them into inputs for a virtual game controller. This allows apps and games that support the standard macOS GameController framework to work seamlessly with Wii peripherals.

## Prerequisites

- **macOS**: 14.0 (Sonoma) or later.
- **Hardware**: Apple Silicon Mac (recommended) with Bluetooth support.
- **Controllers**: Wii Remote (RVL-001) or Wii U Pro Controller.

## Installation and Build Instructions

1.  **Clone the repository**:
    ```bash
    git clone https://github.com/FaiGiJoon/WiiBridge-Nintendo-Controller-HID-Bridge-for-macOS.git
    cd WiiBridge-Nintendo-Controller-HID-Bridge-for-macOS
    ```
2.  **Open in Xcode**:
    Open the root directory or `Package.swift` in Xcode.
3.  **Build and Run**:
    Select the `WiiBridge` target and your Mac as the destination, then press `Cmd+R`.
4.  **Pairing**:
    - Click the WiiBridge icon in the menu bar.
    - Click "Pair New Device".
    - Press the Sync button on your Wii Remote or Wii U Pro Controller.
    - The controller should appear in the list; click "Pair".

## Features

- **Swift Concurrency**: Utilizes `async/await` and `AsyncStream` for responsive UI and stable Bluetooth management.
- **Virtual Controller**: Bridges to `GCVirtualController` for broad compatibility.
- **Multiple Controllers**: Supports up to 4 simultaneous connections.
- **Battery Monitoring**: Real-time battery level display in the menu.
- **Rumble Support**: Basic rumble functionality.
- **Motion Support**: Maps Wii Remote accelerometer data.

## Roadmap

- [ ] **Nunchuk Support**: Complete mapping for Nunchuk analog stick and buttons.
- [ ] **Classic Controller Support**: Support for Classic Controller and Classic Controller Pro extensions.
- [ ] **Advanced Motion**: Improved mapping for MotionPlus and gravity-based tilt.
- [ ] **Custom Profiles**: User-definable button mapping profiles.

## Security

WiiBridge adheres to the principle of least privilege, requesting only the necessary entitlements (`com.apple.security.device.bluetooth` and `com.apple.security.app-sandbox`) and using hardened runtime-compatible practices.
