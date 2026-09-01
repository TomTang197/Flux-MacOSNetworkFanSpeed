import Foundation

struct SensorInfo: Identifiable, Equatable {
    let id: String
    let name: String
    var temperature: Double
    var isEnabled: Bool
    let sampledAt: Date

    init(
        id: String,
        name: String,
        temperature: Double,
        isEnabled: Bool,
        sampledAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.temperature = temperature
        self.isEnabled = isEnabled
        self.sampledAt = sampledAt
    }

    static func == (lhs: SensorInfo, rhs: SensorInfo) -> Bool {
        // Sampling metadata drives fan safety directly, but intentionally does not
        // trigger a UI repaint when the displayed value itself is unchanged.
        lhs.id == rhs.id
            && lhs.name == rhs.name
            && lhs.temperature == rhs.temperature
            && lhs.isEnabled == rhs.isEnabled
    }
}
