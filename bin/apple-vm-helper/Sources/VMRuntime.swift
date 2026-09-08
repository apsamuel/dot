import Foundation

// MARK: - VM Runtime State

struct VMRuntimeState: Codable {
    var name: String
    var bundlePath: String
    var pid: Int?
    var launchedAt: Date?
    var state: String = "unknown"  // unknown, running, stopped, suspended
    var helperVersion: String = "0.1.0-swift"
}

// MARK: - VM Runtime Manager

class VMRuntimeManager {
    let vmRootDir: String

    init(vmRootDir: String) {
        self.vmRootDir = vmRootDir
    }

    private func runtimeFile(for vmName: String) -> String {
        return "\(vmRootDir)/\(vmName)/.runtime.json"
    }

    func loadState(for vmName: String) -> VMRuntimeState? {
        let path = runtimeFile(for: vmName)
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            return try JSONDecoder().decode(VMRuntimeState.self, from: data)
        } catch {
            return nil
        }
    }

    func saveState(_ state: VMRuntimeState, for vmName: String) throws {
        let path = runtimeFile(for: vmName)
        let dir = (path as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(state)
        try data.write(to: URL(fileURLWithPath: path))
    }

    func deleteState(for vmName: String) throws {
        let path = runtimeFile(for: vmName)
        if FileManager.default.fileExists(atPath: path) {
            try FileManager.default.removeItem(atPath: path)
        }
    }

    func discoverBundles() -> [String] {
        guard FileManager.default.fileExists(atPath: vmRootDir) else { return [] }
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: vmRootDir)
            return contents
                .filter { !$0.hasPrefix(".") }
                .filter { isBundle(at: "\(vmRootDir)/\($0)") }
                .sorted()
        } catch {
            return []
        }
    }

    // A directory qualifies as a VM bundle only if it carries a recognized VM marker,
    // so an arbitrary --root (e.g. "/") no longer reports ordinary folders as VMs.
    private static let bundleMarkerFiles = [
        "config.json",      // vmctl bundle config (ssh details)
        "vm.json",          // alternate bundle config name
        ".runtime.json",    // helper runtime state
        "disk.img",         // primary disk image
        "AuxiliaryStorage", // Virtualization.framework auxiliary storage
        "nvram",            // VZ EFI NVRAM store
    ]
    private static let bundleExtensions = [".bundle", ".vm", ".vzvm"]

    private func isBundle(at path: String) -> Bool {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { return false }
        let name = (path as NSString).lastPathComponent
        if Self.bundleExtensions.contains(where: { name.hasSuffix($0) }) { return true }
        let fm = FileManager.default
        return Self.bundleMarkerFiles.contains { fm.fileExists(atPath: "\(path)/\($0)") }
    }

    func isPidAlive(_ pid: Int) -> Bool {
        return kill(pid_t(pid), 0) == 0
    }

    func findProcessPid(for vmName: String, bundlePath: String) -> Int? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-axo", "pid=,command="]

        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            // Read first to avoid deadlock when ps output exceeds pipe buffer.
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            guard let output = String(data: data, encoding: .utf8) else { return nil }

            for line in output.split(separator: "\n") {
                let parts = line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
                guard parts.count == 2 else { continue }
                guard let pid = Int(parts[0]) else { continue }

                let command = String(parts[1])
                // Look for vz process running this bundle
                if command.contains("vz") && command.contains("run") && command.contains(bundlePath) {
                    return pid
                }
            }
        } catch {
            return nil
        }

        return nil
    }
}
