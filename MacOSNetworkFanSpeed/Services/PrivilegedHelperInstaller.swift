import Foundation
import os.log

final class PrivilegedHelperInstaller {
    static let shared = PrivilegedHelperInstaller()

    let serviceIdentifier = "com.bandan.me.MacOSNetworkFanSpeed.FanService"
    private let helperExecutableName = "FanPrivilegedHelper"
    private let logger = Logger(
        subsystem: "com.bandan.me.MacOSNetworkFanSpeed",
        category: "PrivilegedHelperInstaller"
    )

    private var launchdPlistName: String {
        "\(serviceIdentifier).plist"
    }

    private var installedHelperPath: String {
        "/Library/PrivilegedHelperTools/\(serviceIdentifier)"
    }

    private var installedLaunchdPlistPath: String {
        "/Library/LaunchDaemons/\(launchdPlistName)"
    }

    private init() {}

    func isInstalled() -> Bool {
        let fileManager = FileManager.default
        return fileManager.fileExists(atPath: installedHelperPath)
            && fileManager.fileExists(atPath: installedLaunchdPlistPath)
    }

    func install(completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let sources = try self.resolveInstallSources()
                try self.installWithAdministratorPrivileges(
                    helperSourcePath: sources.helperSourcePath,
                    plistSourcePath: sources.plistSourcePath
                )
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } catch {
                self.logger.error("Helper install failed: \(error.localizedDescription, privacy: .public)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    private func resolveInstallSources() throws -> (helperSourcePath: String, plistSourcePath: String) {
        let fileManager = FileManager.default

        let helperCandidates: [String] = [
            Bundle.main.bundleURL
                .deletingLastPathComponent()
                .appendingPathComponent(helperExecutableName)
                .path,
            Bundle.main.bundleURL
                .appendingPathComponent("Contents/Library/LaunchServices/\(helperExecutableName)")
                .path,
            URL(fileURLWithPath: fileManager.currentDirectoryPath)
                .appendingPathComponent(helperExecutableName)
                .path,
        ]

        let plistCandidates: [String] = [
            Bundle.main.bundleURL
                .appendingPathComponent("Contents/Library/LaunchServices/\(launchdPlistName)")
                .path,
            URL(fileURLWithPath: fileManager.currentDirectoryPath)
                .appendingPathComponent(launchdPlistName)
                .path,
        ]

        let existingHelperCandidates = helperCandidates
            .removingDuplicates()
            .filter { fileManager.fileExists(atPath: $0) }

        guard !existingHelperCandidates.isEmpty else {
            throw InstallerError.missingHelperBinary(
                searchedPaths: helperCandidates
            )
        }

        let helperSourcePath = selectBestHelperCandidate(from: existingHelperCandidates)

        let existingPlistCandidates = plistCandidates
            .removingDuplicates()
            .filter { fileManager.fileExists(atPath: $0) }

        guard !existingPlistCandidates.isEmpty else {
            throw InstallerError.missingLaunchdPlist(
                searchedPaths: plistCandidates
            )
        }

        let plistSourcePath = existingPlistCandidates.first!

        return (helperSourcePath, plistSourcePath)
    }

    private func selectBestHelperCandidate(from candidates: [String]) -> String {
        let fileManager = FileManager.default

        let rankedCandidates = candidates.map { path in
            let attributes = try? fileManager.attributesOfItem(atPath: path)
            let modifiedAt = attributes?[.modificationDate] as? Date ?? .distantPast
            let supportsMachService = helperBinaryLooksCurrent(at: path)
            return (path: path, modifiedAt: modifiedAt, supportsMachService: supportsMachService)
        }

        let sorted = rankedCandidates.sorted { lhs, rhs in
            if lhs.supportsMachService != rhs.supportsMachService {
                return lhs.supportsMachService && !rhs.supportsMachService
            }
            if lhs.modifiedAt != rhs.modifiedAt {
                return lhs.modifiedAt > rhs.modifiedAt
            }
            return lhs.path < rhs.path
        }

        if let selected = sorted.first {
            logger.notice(
                "Selected helper source: \(selected.path, privacy: .public) (supportsMachService=\(selected.supportsMachService, privacy: .public))"
            )
            return selected.path
        }

        return candidates[0]
    }

    private func helperBinaryLooksCurrent(at path: String) -> Bool {
        guard let data = FileManager.default.contents(atPath: path) else { return false }
        guard let binaryText = String(data: data, encoding: .isoLatin1) else { return false }

        // Current helper entrypoint is expected to include mach-service listener symbols.
        return binaryText.contains("initWithMachServiceName:")
            || binaryText.contains("machServiceName:")
    }

    private func installWithAdministratorPrivileges(helperSourcePath: String, plistSourcePath: String) throws {
        let command = [
            "/usr/bin/install -d -m 755 /Library/PrivilegedHelperTools",
            "/usr/bin/install -m 755 \(shellQuote(helperSourcePath)) \(shellQuote(installedHelperPath))",
            "/usr/sbin/chown root:wheel \(shellQuote(installedHelperPath))",
            "/usr/bin/install -d -m 755 /Library/LaunchDaemons",
            "/usr/bin/install -m 644 \(shellQuote(plistSourcePath)) \(shellQuote(installedLaunchdPlistPath))",
            "/usr/sbin/chown root:wheel \(shellQuote(installedLaunchdPlistPath))",
            "/bin/launchctl bootout system/\(serviceIdentifier) >/dev/null 2>&1 || true",
            "/bin/launchctl bootstrap system \(shellQuote(installedLaunchdPlistPath))",
            "/bin/launchctl enable system/\(serviceIdentifier)",
            "/bin/launchctl kickstart -k system/\(serviceIdentifier)",
        ].joined(separator: "; ")

        let script = "do shell script \"\(escapeForAppleScript(command))\" with administrator privileges"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let stdOut = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let stdErr = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let message = [stdErr, stdOut]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first(where: { !$0.isEmpty }) ?? "Unknown install error"
            throw InstallerError.installCommandFailed(message: message)
        }
    }

    private func escapeForAppleScript(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\"'\"'"))'"
    }
}

private extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

extension PrivilegedHelperInstaller {
    enum InstallerError: LocalizedError {
        case missingHelperBinary(searchedPaths: [String])
        case missingLaunchdPlist(searchedPaths: [String])
        case installCommandFailed(message: String)

        var errorDescription: String? {
            switch self {
            case let .missingHelperBinary(searchedPaths):
                return
                    "Helper executable not found. Looked in: \(searchedPaths.joined(separator: ", "))"
            case let .missingLaunchdPlist(searchedPaths):
                return
                    "Launchd plist not found. Looked in: \(searchedPaths.joined(separator: ", "))"
            case let .installCommandFailed(message):
                return "Install command failed: \(message)"
            }
        }
    }
}
