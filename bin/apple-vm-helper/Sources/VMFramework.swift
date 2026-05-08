import Foundation

// MARK: - VM Framework Manager

class VMFrameworkManager {
    let runtimeManager: VMRuntimeManager

    init(vmRootDir: String) {
        self.runtimeManager = VMRuntimeManager(vmRootDir: vmRootDir)
    }

    // MARK: - VM Discovery

    func listVMs() -> [VMInfo] {
        let bundles = runtimeManager.discoverBundles()
        return bundles.map { vmName in
            let bundlePath = "\(runtimeManager.vmRootDir)/\(vmName)"
            var status = "stopped"

            // Try to load state and check if process is alive
            if let state = runtimeManager.loadState(for: vmName) {
                if let pid = state.pid, runtimeManager.isPidAlive(pid) {
                    status = "running"
                } else {
                    // State file exists but process is gone
                    try? runtimeManager.deleteState(for: vmName)
                    status = "stopped"
                }
            } else {
                // No state file; check if a process is running
                if let pid = runtimeManager.findProcessPid(for: vmName, bundlePath: bundlePath) {
                    status = "running"
                    // Recover state
                    var recovered = VMRuntimeState(name: vmName, bundlePath: bundlePath)
                    recovered.pid = pid
                    recovered.state = "running"
                    try? runtimeManager.saveState(recovered, for: vmName)
                }
            }

            return VMInfo(name: vmName, status: status, id: vmName)
        }
    }

    // MARK: - Lifecycle Operations

    func startVM(bundlePath: String, vmName: String) -> (success: Bool, state: String, error: String?) {
        // Check if already running
        if let state = runtimeManager.loadState(for: vmName),
           let pid = state.pid,
           runtimeManager.isPidAlive(pid) {
            return (true, "running", nil)
        }

        // TODO: Implement actual Virtualization.framework launch
        // For now, attempt vz CLI as fallback
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        task.arguments = ["vz"]

        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            task.waitUntilExit()

            if task.terminationStatus == 0 {
                // vz is available; use it as launch method
                let launchTask = Process()
                launchTask.executableURL = URL(fileURLWithPath: "/usr/local/bin/vz")
                launchTask.arguments = ["run", bundlePath]
                launchTask.standardOutput = FileHandle.nullDevice
                launchTask.standardError = FileHandle.nullDevice

                try launchTask.run()

                // Record state
                var state = VMRuntimeState(name: vmName, bundlePath: bundlePath)
                state.launchedAt = Date()
                state.state = "running"
                // Note: We don't have the actual PID from detached launch; will discover via process scan
                try? runtimeManager.saveState(state, for: vmName)

                return (true, "running", nil)
            } else {
                return (false, "stopped", "vz CLI not available; native Virtualization.framework not yet implemented")
            }
        } catch {
            return (false, "stopped", error.localizedDescription)
        }
    }

    func stopVM(vmName: String, gracePeriod: Int) -> (success: Bool, state: String, error: String?) {
        guard let state = runtimeManager.loadState(for: vmName) else {
            return (true, "stopped", nil)
        }

        guard let pid = state.pid, runtimeManager.isPidAlive(pid) else {
            try? runtimeManager.deleteState(for: vmName)
            return (true, "stopped", nil)
        }

        // Send SIGTERM
        if kill(pid_t(pid), SIGTERM) != 0 {
            return (false, "unknown", "failed to send SIGTERM to pid \(pid)")
        }

        // Wait up to gracePeriod seconds
        let deadline = Date().addingTimeInterval(TimeInterval(gracePeriod))
        while Date() < deadline {
            if !runtimeManager.isPidAlive(pid) {
                try? runtimeManager.deleteState(for: vmName)
                return (true, "stopped", nil)
            }
            usleep(200000) // 200ms
        }

        // Still alive; try SIGKILL
        if kill(pid_t(pid), SIGKILL) == 0 {
            usleep(500000) // Wait a bit
            if !runtimeManager.isPidAlive(pid) {
                try? runtimeManager.deleteState(for: vmName)
                return (true, "stopped", nil)
            }
        }

        return (false, "running", "VM did not stop after \(gracePeriod)s")
    }

    func suspendVM(vmName: String) -> (success: Bool, state: String, error: String?) {
        // TODO: Implement via Virtualization.framework pause API
        return (false, "unknown", "suspend not yet implemented; requires Virtualization.framework integration")
    }

    func resumeVM(vmName: String) -> (success: Bool, state: String, error: String?) {
        // TODO: Implement via Virtualization.framework resume API
        return (false, "unknown", "resume not yet implemented; requires Virtualization.framework integration")
    }

    func statusVM(vmName: String) -> (state: String, detail: String?) {
        guard let state = runtimeManager.loadState(for: vmName) else {
            return ("unknown", "no state file found")
        }

        if let pid = state.pid, runtimeManager.isPidAlive(pid) {
            return ("running", "pid \(pid)")
        }

        try? runtimeManager.deleteState(for: vmName)
        return ("stopped", nil)
    }
}
