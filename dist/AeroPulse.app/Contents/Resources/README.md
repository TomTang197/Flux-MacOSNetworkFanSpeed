# AeroPulse

AeroPulse is a macOS menu bar and dashboard monitor for real-time hardware and throughput telemetry.

This project is a fork and evolution of [Flux-MacOSNetworkFanSpeed](https://github.com/BkMahto/Flux-MacOSNetworkFanSpeed), with a stronger focus on dashboard UX polish, stable read-only monitoring, and practical daily-use metrics.

## What AeroPulse Monitors

- Network download/upload speed + cumulative totals
- Disk read/write speed + cumulative totals
- Disk capacity (total / free / used ratio)
- CPU usage and memory usage
- Fan RPM and thermal sensors (CPU / GPU / System grouping)

## Product Direction

- Read-only by default for safety and compatibility
- Menu bar compact layout with fixed visual rhythm
- Desktop dashboard with multi-column cards and thermal detail view
- Launch at login support (status bar workflow)
- In-app bug feedback entry

## Current Note on Fan Control

Manual fan write operations are intentionally disabled in this branch.  
The app currently focuses on reliable telemetry, while helper-related pieces are kept for compatibility/diagnostics rather than active fan override control.

## Build & Run

### Requirements

- Xcode 17+
- Swift 5
- Project currently targets modern macOS SDK/deployment settings (as configured in `AeroPulse.xcodeproj`)

### Local Build

```bash
xcodebuild -project AeroPulse.xcodeproj -scheme AeroPulse -configuration Debug build
```

Open in Xcode:

1. Open `AeroPulse.xcodeproj`
2. Select scheme `AeroPulse`
3. Run on your Mac

## Fork Acknowledgement

This repository started from:

- Upstream: [BkMahto/Flux-MacOSNetworkFanSpeed](https://github.com/BkMahto/Flux-MacOSNetworkFanSpeed)

Respect to the original author and contributors for the foundation work on SMC/network monitoring and app structure.

If you redistribute this fork or create further derivatives, keep upstream attribution and license notices intact.

## License

MIT License.  
See [`LICENSE`](LICENSE) for full text and attribution.
