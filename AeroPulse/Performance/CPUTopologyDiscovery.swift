import Darwin
import Foundation

public enum AppleSiliconGeneration: Equatable, Sendable {
    case intel
    case m1(variant: Variant)
    case m2(variant: Variant)
    case m3(variant: Variant)
    case m4(variant: Variant)
    case m5(variant: Variant)
    case unknownAppleSilicon

    public enum Variant: String, Equatable, Sendable {
        case base
        case pro
        case max
        case ultra
    }

    public var generationNumber: Int {
        switch self {
        case .intel: return 0
        case .m1: return 1
        case .m2: return 2
        case .m3: return 3
        case .m4: return 4
        case .m5: return 5
        case .unknownAppleSilicon: return -1
        }
    }

    public var hasSuperCores: Bool {
        if case .m5 = self { return true }
        return false
    }

    public static func detect(brand: String? = nil) -> AppleSiliconGeneration {
        let cpuBrand = (brand ?? readCPUBrand()).lowercased()
        guard cpuBrand.contains("apple") else { return .intel }

        let variant: Variant
        if cpuBrand.contains("ultra") {
            variant = .ultra
        } else if cpuBrand.contains("max") {
            variant = .max
        } else if cpuBrand.contains("pro") {
            variant = .pro
        } else {
            variant = .base
        }

        let words = cpuBrand.split { !$0.isLetter && !$0.isNumber }
        if words.contains("m1") { return .m1(variant: variant) }
        if words.contains("m2") { return .m2(variant: variant) }
        if words.contains("m3") { return .m3(variant: variant) }
        if words.contains("m4") { return .m4(variant: variant) }
        if words.contains("m5") { return .m5(variant: variant) }

        return .unknownAppleSilicon
    }

    public static func readCPUBrand() -> String {
        var size = 0
        guard sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0) == 0, size > 1 else {
            return ""
        }
        var value = [CChar](repeating: 0, count: size)
        guard sysctlbyname("machdep.cpu.brand_string", &value, &size, nil, 0) == 0 else {
            return ""
        }
        return String(cString: value)
    }
}

public struct CPUTierInfo: Identifiable, Equatable, Sendable {
    public var id: Int { level }
    public let level: Int
    public let name: String
    public let tier: CPUSensorTier
    public let physicalCount: Int
    public let logicalCount: Int

    public init(
        level: Int,
        name: String,
        tier: CPUSensorTier,
        physicalCount: Int,
        logicalCount: Int
    ) {
        self.level = level
        self.name = name
        self.tier = tier
        self.physicalCount = physicalCount
        self.logicalCount = logicalCount
    }
}

public enum CPUTopologyDiscovery {
    public static func appleSiliconGeneration() -> AppleSiliconGeneration {
        AppleSiliconGeneration.detect()
    }

    static func sensorTier(
        level: Int, name: String, levelCount: Int, generation: AppleSiliconGeneration
    ) -> CPUSensorTier {
        guard level >= 0, level < levelCount else { return .other }
        // macOS can retain the old Performance/Efficiency perflevel names on M5.
        // Base M5 is S/E; Pro and Max are S/P. Neither requires three perflevels.
        if case .m5(let variant) = generation, levelCount == 2 {
            switch variant {
            case .base: return level == 0 ? .superCore : .efficiencyCore
            case .pro, .max: return level == 0 ? .superCore : .performanceCore
            case .ultra: break
            }
        }
        let lowerName = name.lowercased()
        if lowerName.contains("super") || lowerName.contains("peak") { return .superCore }
        if lowerName.contains("perf") || lowerName.contains("medium") { return .performanceCore }
        if lowerName.contains("effic") { return .efficiencyCore }
        if (1...4).contains(generation.generationNumber), levelCount == 2 {
            return level == 0 ? .performanceCore : .efficiencyCore
        }
        return .other
    }

    public static func discoverTiers() -> [CPUTierInfo] {
        var nperflevels: Int32 = 0
        var size = MemoryLayout<Int32>.size
        var tiers: [CPUTierInfo] = []
        let generation = AppleSiliconGeneration.detect()

        if sysctlbyname("hw.nperflevels", &nperflevels, &size, nil, 0) == 0, nperflevels > 0 {
            for i in 0..<nperflevels {
                var physical: Int32 = 0
                var logical: Int32 = 0
                var nameBuf = [CChar](repeating: 0, count: 64)
                var nameSize = nameBuf.count

                sysctlbyname("hw.perflevel\(i).physicalcpu", &physical, &size, nil, 0)
                sysctlbyname("hw.perflevel\(i).logicalcpu", &logical, &size, nil, 0)
                sysctlbyname("hw.perflevel\(i).name", &nameBuf, &nameSize, nil, 0)

                let rawName = String(cString: nameBuf).trimmingCharacters(in: .whitespacesAndNewlines)
                guard physical > 0 else { continue }

                let tier = sensorTier(
                    level: Int(i), name: rawName, levelCount: Int(nperflevels),
                    generation: generation
                )

                let displayName: String
                switch tier {
                case .superCore: displayName = "Super"
                case .performanceCore: displayName = "Performance"
                case .efficiencyCore: displayName = "Efficiency"
                default: displayName = rawName.isEmpty ? "Core Level \(i)" : rawName
                }

                tiers.append(
                    CPUTierInfo(
                        level: Int(i),
                        name: displayName,
                        tier: tier,
                        physicalCount: Int(physical),
                        logicalCount: Int(logical > 0 ? logical : physical)
                    )
                )
            }
        }

        if tiers.isEmpty {
            var physical: Int32 = 0
            sysctlbyname("hw.physicalcpu", &physical, &size, nil, 0)
            let count = max(Int(physical), 0)
            tiers.append(
                CPUTierInfo(
                    level: 0,
                    name: "CPU",
                    tier: .other,
                    physicalCount: count,
                    logicalCount: count
                )
            )
        }

        return tiers
    }

    public static func expectedCoreCounts() -> (superCores: Int, performanceCores: Int, efficiencyCores: Int, total: Int) {
        let tiers = discoverTiers()
        var superCount = 0
        var perfCount = 0
        var effCount = 0

        for tier in tiers {
            switch tier.tier {
            case .superCore:
                superCount += tier.physicalCount
            case .performanceCore:
                perfCount += tier.physicalCount
            case .efficiencyCore:
                effCount += tier.physicalCount
            default:
                break
            }
        }

        let total = tiers.reduce(0) { $0 + $1.physicalCount }
        return (superCount, perfCount, effCount, total)
    }
}
