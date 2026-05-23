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

## Detailed Setup Guide

### 1. Pairing a Controller
WiiBridge resides in your macOS menu bar for easy access.

- Click the **WiiBridge icon** (game controller) in the menu bar.
- Click **"Pair New Device"**.
- Press the **Sync button** on your Wii Remote (usually behind the battery cover) or Wii U Pro Controller.
- The controller should appear in the "Found Devices" list.
- Click **"Pair"** next to your device.

![Menu Bar Pairing](docs/screenshots/menu_bar_pairing.png)
*WiiBridge Menu Bar Popover*

### 2. Using the Dashboard
Once connected, you can view your controllers and their real-time inputs in the Main Dashboard.

- Click **"Open Main Dashboard"** from the menu bar popover.
- Select your controller from the sidebar to view:
    - **Battery Level**: Monitored in real-time.
    - **Input Visualization**: A live view of button presses, D-pad movement, and accelerometer data.
    - **uDraw Tablet Surface**: A specialized canvas for the uDraw stylus position and pressure.
- **Button Profiles**: Use the dropdown in the menu bar to switch between "Standard", "Xbox Layout", and "Classic" profiles to change how inputs are mapped to the virtual controller.

![Main Dashboard](docs/screenshots/dashboard.png)
*WiiBridge Dashboard*

## Dolphin Emulator Setup

WiiBridge includes a specialized "Dolphin Optimization" mode to provide the best experience with the Dolphin emulator.

### 1. Enable Compatibility Mode
In the **Device Detail View** or the app **Settings**, ensure that **"Enable Dolphin Compatibility Mode"** is toggled ON. This adjusts report rates and stick deadzones for optimal performance.

### 2. Configure Dolphin
1. Open **Dolphin Emulator**.
2. Click on **Controllers**.
3. Under "Wii Remote 1", select **"Emulated Wii Remote"**.
4. Click **Configure**.
5. In the **Device** dropdown, select the **WiiBridge** virtual controller.
6. Map the buttons as desired. WiiBridge maps the physical Wii inputs to standard GameController inputs which Dolphin can easily recognize.

![Dolphin Controller Settings](docs/screenshots/dolphin_settings.png)
*Dolphin Controller Configuration*

### 3. uDraw Tablet Support
If you are using a uDraw GameTablet, toggle **"Emulate uDraw Tablet via Virtual Joystick"** in WiiBridge.
- In Dolphin's controller configuration, set the **Extension** to **"uDraw Tablet"**.
- The tablet surface will be mapped to the virtual analog sticks, allowing for precise drawing and gameplay within supported titles.

![Dolphin Mapping](docs/screenshots/dolphin_mapping.png)
*Dolphin uDraw Extension Mapping*

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
