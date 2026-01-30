import SwiftUI

/// `MenuBarView` determines which speed values to display in the system menu bar based on the user's selected `DisplayMode`.
struct MenuBarView: View {
    @ObservedObject var viewModel: NetworkViewModel

    var body: some View {
        switch viewModel.displayMode {
        case .download:
            speedLabel(viewModel.downloadSpeed, systemImage: "arrowtriangle.down.fill")
        case .upload:
            speedLabel(viewModel.uploadSpeed, systemImage: "arrowtriangle.up.fill")
        case .both:
            speedLabel(viewModel.combinedSpeed, systemImage: "arrow.up.and.down")
        case .combined:
            // Two-line layout using Text concatenation
            Text("\(viewModel.downloadSpeed) | \(viewModel.uploadSpeed)")
                .font(.system(size: 9, weight: .bold))
                .monospacedDigit()
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func speedLabel(_ speed: String, systemImage: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: systemImage)
                .symbolVariant(.fill)
                .imageScale(.small)
            Text(speed)
        }
    }
}
