# NetworkSpeedMeter

A macOS menu bar application that monitors network speed, fan RPM, and system temperatures with real-time SMC (System Management Controller) integration.

![macOS](https://img.shields.io/badge/macOS-14.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

## Features

### 🌐 Network Monitoring

- Real-time download and upload speed tracking
- Multiple display modes:
    - Download only
    - Upload only
    - Combined (both speeds)
    - Dual view (side-by-side)

### 🌡️ Thermal Monitoring

- Comprehensive sensor support for Apple Silicon and Intel Macs
- CPU temperature averaging across all cores (P-cores, E-cores)
- Individual sensor monitoring:
    - Performance cores (up to 20 sensors for M2/M3 Ultra)
    - Efficiency cores (up to 16 sensors)
    - GPU clusters
    - SSD/Storage temperatures
    - System sensors (battery, ambient, etc.)

### 💨 Fan Control

- Real-time fan RPM monitoring
- Fan control presets:
    - **Automatic**: System-managed fan speeds
    - **Full Blast**: Maximum cooling performance
- Display fan speed in menu bar

### 📊 Menu Bar Integration

- Customizable display modes
- Clean, minimal interface
- Quick access to detailed stats

## Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon (M1/M2/M3) or Intel Mac
- Xcode 15.0+ (for building from source)

## Installation

### Building from Source

1. Clone the repository:

```bash
git clone https://github.com/yourusername/NetworkSpeedMeter.git
cd NetworkSpeedMeter
```

2. Open the project in Xcode:

```bash
open NetworkSpeedMeter.xcodeproj
```

3. Build and run (⌘R)

> **Note**: The app requires access to SMC (System Management Controller) for fan and temperature monitoring. Ensure the app is not sandboxed or has appropriate entitlements.

## Usage

### Menu Bar Display Modes

Click the menu bar icon to access settings and switch between display modes:

- **Network**: Download/Upload speeds
- **Fan**: Current fan RPM
- **Temperature**: Average CPU temperature
- **Combined**: Fan RPM + Temperature

### Fan Control

Access fan control from the menu:

1. Click the menu bar icon
2. Select "Fan Control" or thermal details
3. Choose a preset:
    - **Automatic**: Default system behavior
    - **Full Blast**: Maximum fan speed for intensive tasks

### Thermal Details

View detailed sensor information:

- All detected CPU core temperatures
- GPU cluster temperatures
- Storage temperatures
- System component temperatures

## Technical Details

### SMC Integration

The app uses direct SMC (System Management Controller) communication via IOKit to read sensor data and control fans. Key features:

- **Apple Silicon Support**: Uses Method Index 2 gateway with 80-byte `SMCParamStruct`
- **Sensor Keys**: Centralized in `SMCSensorKeys.swift` for easy maintenance
- **Data Types**: Supports sp78, fpe2, flt, ui16, ui32, ui8 SMC data types

### Architecture

```
NetworkSpeedMeter/
├── Models/           # Data structures (FanInfo, SensorInfo, SMCSensorKeys)
├── Services/         # SMC communication and monitoring
├── ViewModels/       # Business logic and state management
└── Views/            # SwiftUI interface components
```

### Sensor Key Organization

Sensor keys are organized by component type in `SMCSensorKeys.swift`:

- `SMCSensorKeys.CPU.PerformanceCores` - P-core sensors
- `SMCSensorKeys.CPU.EfficiencyCores` - E-core sensors
- `SMCSensorKeys.GPU` - GPU sensors
- `SMCSensorKeys.Storage` - SSD/storage sensors
- `SMCSensorKeys.System` - System component sensors

## Known Limitations

- SMC access may be restricted in sandboxed environments
- Some sensor keys may not be available on all Mac models
- Fan control requires appropriate system permissions

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- SMC protocol research from the macOS community
- Inspired by various Mac monitoring utilities

## Disclaimer

This software interacts with low-level system components (SMC). Use fan control features responsibly. The authors are not responsible for any hardware damage resulting from improper use.

---

**Made with ❤️ for macOS**
