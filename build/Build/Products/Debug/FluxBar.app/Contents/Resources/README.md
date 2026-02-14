# Flux (MacOSNetworkFanSpeed)

A high-fidelity macOS menu bar application that provides real-time telemetry for your system. Monitor network speeds, disk activity, CPU usage, and thermal health with precision.

## Features

- **Unified Menu Bar Icon**: Monitor multiple metrics (download, upload, temperature, etc.) within a single, elegant menu bar item.
- **Live Telemetry**: Real-time tracking of network throughput, disk I/O, and CPU/Memory usage.
- **Thermal Monitor**: Direct SMC integration to read fan RPM and CPU/System temperatures.
- **Liquid Glass UI**: A modern, vibrant dashboard designed to feel at home on the latest macOS versions.
- **Native & Efficient**: Built with SwiftUI and optimized for both Apple Silicon and Intel Macs with minimal system impact.

## Architecture

This application is designed for **Read-Only** monitoring of system sensors and network interfaces. 
- **SMCService**: Handles low-level communication with the AppleSMC driver using IOKit. Supports modern 80-byte structure requirements for Apple Silicon.
- **NetworkMonitor**: Tracks interface statistics via system network counters.
- **Privileged Helper**: No longer required. Flux operates entirely in user-space for enhanced security and simplified installation.

## Installation

1. Clone the repository.
2. Open `MacOSNetworkFanSpeed.xcodeproj` in Xcode 15+.
3. Build and Run.

*Note: Ensure the app has necessary permissions to read system statistics. App Sandbox may need to be disabled for direct SMC access.*

## License

MIT License.
