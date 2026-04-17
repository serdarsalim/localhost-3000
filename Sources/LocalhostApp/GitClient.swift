import Foundation

enum GitClient {
    static func status(at url: URL) async -> GitStatus {
        let isRepo = await shell(["git", "-C", url.path, "rev-parse", "--git-dir"]) != nil
        guard isRepo else { return .unknown }

        let output = await shell(["git", "-C", url.path, "status", "--porcelain"]) ?? ""
        let count = output.split(separator: "\n").filter { !$0.isEmpty }.count
        return GitStatus(isRepo: true, uncommittedCount: count)
    }

    private static func shell(_ args: [String]) async -> String? {
        await Task.detached {
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = args
            process.standardOutput = pipe
            process.standardError = Pipe()
            do {
                try process.run()
                process.waitUntilExit()
                guard process.terminationStatus == 0 else { return nil }
                return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
            } catch {
                return nil
            }
        }.value
    }
}
