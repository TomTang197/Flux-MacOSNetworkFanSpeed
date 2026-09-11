import Foundation

public enum SensorCategory: String, Codable, CaseIterable, Sendable {
    case cpu
    case gpu
    case storage
    case system
}

public enum CPUSensorTier: String, Codable, CaseIterable, Sendable {
    case superCore       // S-Core (M5+)
    case performanceCore // P-Core
    case efficiencyCore  // E-Core
    case diePackage      // TCMb, TC0P, TCMz, mACC
    case other
}

public enum GPUSensorKind: String, Codable, CaseIterable, Sendable {
    case cluster
    case core
    case die
    case average
    case proximity
    case other
}

public struct SensorInfo: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let shortName: String
    public var temperature: Double
    public var isEnabled: Bool
    public let sampledAt: Date
    public let category: SensorCategory
    public let cpuTier: CPUSensorTier?
    public let gpuKind: GPUSensorKind?
    public let coreIndex: Int?

    public init(
        id: String,
        name: String,
        temperature: Double,
        isEnabled: Bool,
        sampledAt: Date = Date(),
        category: SensorCategory? = nil,
        cpuTier: CPUSensorTier? = nil,
        gpuKind: GPUSensorKind? = nil,
        coreIndex: Int? = nil,
        shortName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.temperature = temperature
        self.isEnabled = isEnabled
        self.sampledAt = sampledAt

        let resolvedCategory: SensorCategory
        if let category {
            resolvedCategory = category
        } else if id.hasPrefix("Tg") || id.hasPrefix("TG") || id == "vACC" || name.localizedCaseInsensitiveContains("GPU") {
            resolvedCategory = .gpu
        } else if id.hasPrefix("TC") || id.hasPrefix("Te") || id.hasPrefix("Tp") || id.hasPrefix("Tf")
                    || name.localizedCaseInsensitiveContains("Core") || name.localizedCaseInsensitiveContains("CPU") {
            resolvedCategory = .cpu
        } else if (id.hasPrefix("Ts") || id.hasPrefix("TH")) && (name.localizedCaseInsensitiveContains("NAND") || name.localizedCaseInsensitiveContains("SSD") || name.localizedCaseInsensitiveContains("Storage")) {
            resolvedCategory = .storage
        } else {
            resolvedCategory = .system
        }
        self.category = resolvedCategory

        if let cpuTier {
            self.cpuTier = cpuTier
        } else if resolvedCategory == .cpu {
            if name.localizedCaseInsensitiveContains("super") || name.localizedCaseInsensitiveContains("s-core") {
                self.cpuTier = .superCore
            } else if name.localizedCaseInsensitiveContains("performance") || name.localizedCaseInsensitiveContains("p-core") {
                self.cpuTier = .performanceCore
            } else if name.localizedCaseInsensitiveContains("efficiency") || name.localizedCaseInsensitiveContains("e-core") {
                self.cpuTier = .efficiencyCore
            } else if ["TCMb", "TCMz", "TC0P", "mACC"].contains(id) {
                self.cpuTier = .diePackage
            } else {
                self.cpuTier = .other
            }
        } else {
            self.cpuTier = nil
        }

        if let gpuKind {
            self.gpuKind = gpuKind
        } else if resolvedCategory == .gpu {
            if id == "vACC" || name.localizedCaseInsensitiveContains("average") {
                self.gpuKind = .average
            } else if id == "TG0P" || name.localizedCaseInsensitiveContains("proximity") {
                self.gpuKind = .proximity
            } else if ["TGMb", "TGMz"].contains(id) {
                self.gpuKind = .die
            } else if name.localizedCaseInsensitiveContains("cluster") {
                self.gpuKind = .cluster
            } else {
                self.gpuKind = .core
            }
        } else {
            self.gpuKind = nil
        }

        self.coreIndex = coreIndex
        self.shortName = shortName ?? Self.defaultShortName(
            id: id,
            name: name,
            category: resolvedCategory,
            cpuTier: self.cpuTier,
            gpuKind: self.gpuKind,
            coreIndex: coreIndex
        )
    }

    public static func == (lhs: SensorInfo, rhs: SensorInfo) -> Bool {
        // Sampling metadata drives fan safety directly, but intentionally does not
        // trigger a UI repaint when the displayed value itself is unchanged.
        lhs.id == rhs.id
            && lhs.name == rhs.name
            && lhs.shortName == rhs.shortName
            && lhs.temperature == rhs.temperature
            && lhs.isEnabled == rhs.isEnabled
            && lhs.category == rhs.category
            && lhs.cpuTier == rhs.cpuTier
            && lhs.gpuKind == rhs.gpuKind
            && lhs.coreIndex == rhs.coreIndex
    }

    public static func defaultShortName(
        id: String,
        name: String,
        category: SensorCategory,
        cpuTier: CPUSensorTier?,
        gpuKind: GPUSensorKind?,
        coreIndex: Int?
    ) -> String {
        if let coreIndex {
            switch cpuTier {
            case .superCore: return "S\(coreIndex)"
            case .performanceCore: return "P\(coreIndex)"
            case .efficiencyCore: return "E\(coreIndex)"
            default: break
            }
            if category == .gpu {
                return "G\(coreIndex)"
            }
        }

        switch id {
        case "TCMb": return "Die"
        case "TCMz": return "Hotspot"
        case "TC0P": return cpuTier == .diePackage ? "Pkg" : "Prox"
        case "mACC": return "Avg"
        case "vACC": return "Avg"
        case "TG0P": return "Prox"
        default: break
        }

        // Clean prefix parsing fallback
        for (prefix, label) in [
            ("S-Core Sensor ", "S"),
            ("P-Core Sensor ", "P"),
            ("E-Core Sensor ", "E"),
            ("GPU Core Sensor ", "G"),
            ("GPU Sensor ", "G"),
            ("GPU Cluster ", "G"),
            ("CPU Core ", "C"),
        ] where name.hasPrefix(prefix) {
            let remainder = name.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
            return "\(label)\(remainder)"
        }

        return name
    }
}
