import SwiftUI

/// `SettingsView` provides a unified UI for configuring the app, used in both the menu bar and the main window.
struct SettingsView: View {
  @ObservedObject var viewModel: NetworkViewModel

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      // Header
      Button {
          // 
      } label: {
        HStack {
          Text("Network Speed")
            .font(.headline)
          Spacer()
          Image(systemName: "gauge.with.dots.needle.bottom.50percent")
            .foregroundColor(.secondary)
        }
      }

      Divider()

      // Real-time stats display
      VStack(spacing: 0) {
        StatRow(
          icon: "arrow.down.circle.fill",
          label: "Download",
          value: viewModel.downloadSpeed,
          color: .blue
        )
        .padding(.vertical, 8)
        Divider().opacity(0.3)
        StatRow(
          icon: "arrow.up.circle.fill",
          label: "Upload",
          value: viewModel.uploadSpeed,
          color: .green
        )
        .padding(.vertical, 8)
      }
      .padding(.horizontal, 12)
      .background(
        RoundedRectangle(cornerRadius: 10)
          .fill(Color.primary.opacity(0.03))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 10)
          .stroke(Color.primary.opacity(0.08), lineWidth: 1)
      )

      // Configuration controls
      VStack(alignment: .leading, spacing: 12) {
        VStack(alignment: .leading, spacing: 6) {
          Label("Display Mode", systemImage: "macwindow.badge.plus")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.secondary)

          Picker("", selection: $viewModel.displayMode) {
            Text("Down").tag(DisplayMode.download)
            Text("Up").tag(DisplayMode.upload)
            Text("Total").tag(DisplayMode.both)
            Text("Dual").tag(DisplayMode.combined)
          }
          .pickerStyle(.segmented)
          .labelsHidden()
        }

        HStack {
          Label("Refresh", systemImage: "arrow.clockwise.circle")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.secondary)
          Spacer()
          Picker("", selection: $viewModel.refreshInterval) {
            Text("0.5s").tag(0.5)
            Text("1.0s").tag(1.0)
            Text("2.0s").tag(2.0)
            Text("5.0s").tag(5.0)
          }
          .pickerStyle(.menu)
          .frame(width: 70)
        }
      }

      Divider().opacity(0.3)

      Button(
        role: .destructive,
        action: {
          NSApplication.shared.terminate(nil)
        }
      ) {
        HStack {
          Image(systemName: "power.circle.fill")
          Text("Quit Application")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.regular)
      .tint(.red.opacity(0.8))
    }
    .padding(16)
    .frame(width: 280)
  }
}

private struct StatRow: View {
  let icon: String
  let label: String
  let value: String
  let color: Color

  var body: some View {
    HStack {
      Image(systemName: icon)
        .foregroundColor(color)
        .font(.title3)
      Text(label)
        .font(.subheadline)
      Spacer()
      Text(value)
        .font(.system(.body, design: .monospaced))
        .fontWeight(.bold)
    }
  }
}
