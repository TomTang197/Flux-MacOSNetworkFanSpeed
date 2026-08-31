import Foundation

struct SensorInfo: Identifiable, Equatable {
    let id: String
    let name: String
    var temperature: Double
    var isEnabled: Bool
}
