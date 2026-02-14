## Privileged Fan Helper (Apple Silicon) – Setup Notes

This app is already structured so writes to fan-related SMC keys go through a single abstraction (`FanControlClient`). Right now, the client calls `SMCService` directly, which will fail with `kIOReturnNotPrivileged` for fan writes on Apple Silicon. The next step is to introduce a privileged helper tool that performs those writes on your behalf.

### 1. Add a privileged helper target

- **Create a new macOS Command Line Tool target** in Xcode (language Swift or Objective‑C).
- Name it something like `FanPrivilegedHelper`.
- Set its **Bundle Identifier** to a reverse-DNS string, e.g. `com.bandan.me.AeroPulse.FanPrivilegedHelper`.
- Ensure its product is installed into `/Library/PrivilegedHelperTools` (SMJobBless convention).

### 2. Configure SMJobBless

Follow Apple's “EvenBetterAuthorizationSample” / SMJobBless documentation:

- Add a **launchd property list** (e.g. `com.bandan.me.AeroPulse.FanPrivilegedHelper.plist`) with:
  - `Label` matching the helper bundle ID.
  - `ProgramArguments` pointing at the helper executable.
  - `MachServices` exposing a mach service name for XPC (e.g. `com.bandan.me.AeroPulse.FanService`).
- Embed this plist in the **main app bundle** under `Contents/Library/LaunchServices`.
- Add the `SMPrivilegedExecutables` dictionary to the **main app's Info.plist**, mapping the helper bundle ID to the embedded launchd plist.

### 3. Code signing and entitlements

- Give the helper target an entitlement file with:
  - `com.apple.developer.privileged-helper` set to `true`.
- Assign a valid **Developer ID Application** or **Mac Development** signing identity to:
  - The main app target.
  - The helper target.
- Make sure the app and helper share the same **Team ID**.

### 4. Implement the helper logic

Inside the helper target:

- Open the `AppleSMC` service with:
  - `IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))`
  - `IOServiceOpen(service, mach_task_self_, 2, &connection)`  // type 2 for privileged writes
- Implement functions such as:
  - `setFanMode(index: Int, manual: Bool)`
  - `setFanTargetRPM(index: Int, rpm: Int)`
  using the same SMC encoding logic currently in `SMCService`.
- Expose these functions over XPC using the mach service name from the launchd plist.

### 5. Wire `FanControlClient` to the helper

In `FanControlClient`:

- Replace the direct `SMCService` calls with XPC calls to the helper:
  - Establish an `NSXPCConnection` (or equivalent) to the helper's mach service.
  - Send `setFanMode` / `setFanTargetRPM` requests to the helper.
- Keep the existing direct `SMCService` writes as a **fallback**:
  - If the helper is not installed or XPC connection fails, continue to call `SMCService` so Intel Macs and development builds still behave as before.

### 6. Bless and test

- From the main app, call `SMJobBless` once (typically at first launch or when the user enables manual/full-blast fan control) to:
  - Install and register the helper under launchd.
- Verify that:
  - The helper is present in `/Library/PrivilegedHelperTools`.
  - Fan writes no longer fail with `kIOReturnNotPrivileged` on Apple Silicon when using manual or full-blast presets.

Once these steps are completed, the existing UI (`FanViewModel` + presets) will automatically use the helper via `FanControlClient`, enabling full-blast and manual fan control where the platform and hardware allow it.

### Quick local install (development)

For local testing without SMJobBless integration, use the scripts in `scripts/`:

```bash
# Build helper first
xcodebuild -project AeroPulse.xcodeproj -scheme FanPrivilegedHelper -configuration Debug build

# Install helper + launchd service
sudo ./scripts/install_helper.sh

# Verify
launchctl print system/com.bandan.me.AeroPulse.FanService | head -n 40
```

To remove:

```bash
sudo ./scripts/uninstall_helper.sh
```
