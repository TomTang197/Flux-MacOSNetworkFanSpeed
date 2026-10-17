import Foundation

public enum ScheduledFanTarget: String, Codable, CaseIterable, Equatable, Identifiable {
    case auto = "Auto"
    case fullBlast = "Max"
    case manual = "Manual"
    case custom = "Rules"

    public var id: String { rawValue }
}

public struct FanScheduleConfig: Codable, Equatable {
    public var isEnabled: Bool
    public var startHour: Int
    public var startMinute: Int
    public var endHour: Int
    public var endMinute: Int
    public var scheduledMode: ScheduledFanTarget
    public var defaultMode: ScheduledFanTarget

    public init(
        isEnabled: Bool = false,
        startHour: Int = 23,
        startMinute: Int = 0,
        endHour: Int = 8,
        endMinute: Int = 0,
        scheduledMode: ScheduledFanTarget = .auto,
        defaultMode: ScheduledFanTarget = .custom
    ) {
        self.isEnabled = isEnabled
        self.startHour = max(0, min(23, startHour))
        self.startMinute = max(0, min(59, startMinute))
        self.endHour = max(0, min(23, endHour))
        self.endMinute = max(0, min(59, endMinute))
        self.scheduledMode = scheduledMode
        self.defaultMode = defaultMode
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        let rawStartHour = try container.decode(Int.self, forKey: .startHour)
        let rawStartMinute = try container.decode(Int.self, forKey: .startMinute)
        let rawEndHour = try container.decode(Int.self, forKey: .endHour)
        let rawEndMinute = try container.decode(Int.self, forKey: .endMinute)
        self.startHour = max(0, min(23, rawStartHour))
        self.startMinute = max(0, min(59, rawStartMinute))
        self.endHour = max(0, min(23, rawEndHour))
        self.endMinute = max(0, min(59, rawEndMinute))
        self.scheduledMode = try container.decode(ScheduledFanTarget.self, forKey: .scheduledMode)
        self.defaultMode = try container.decode(ScheduledFanTarget.self, forKey: .defaultMode)
    }
}
