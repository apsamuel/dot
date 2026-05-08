import Foundation

// MARK: - Models

struct VMInfo: Codable {
    let name: String
    let status: String
    let id: String
}

struct ListResponse: Codable {
    let vms: [VMInfo]
}

struct StatusResponse: Codable {
    let state: String
    let detail: String?
}

struct ActionResponse: Codable {
    let state: String
}

struct VersionResponse: Codable {
    let version: String
}

struct ErrorResponse: Codable {
    let error: String
}

// MARK: - Helpers

func printJSON<T: Encodable>(_ value: T) {
    let encoder = JSONEncoder()
    if let data = try? encoder.encode(value),
       let json = String(data: data, encoding: .utf8) {
        print(json)
    }
}

func printError(_ message: String, exitCode: Int32 = 1) -> Never {
    fputs("[error] \(message)\n", stderr)
    exit(exitCode)
}

// MARK: - Commands

// MARK: - Global Framework Manager

var vmManager: VMFrameworkManager!

func cmdVersion() {
    let response = VersionResponse(version: "0.1.0-swift")
    printJSON(response)
}

func cmdList(root: String) {
    vmManager = VMFrameworkManager(vmRootDir: root)
    let vms = vmManager.listVMs()
    let response = ListResponse(vms: vms)
    printJSON(response)
}

func cmdStart(bundle: String, name: String) {
    let (success, state, error) = vmManager.startVM(bundlePath: bundle, vmName: name)
    if success {
        let response = ActionResponse(state: state)
        printJSON(response)
    } else {
        printError(error ?? "failed to start VM", exitCode: 1)
    }
}

func cmdStop(name: String, grace: Int) {
    let (success, state, error) = vmManager.stopVM(vmName: name, gracePeriod: grace)
    if success {
        let response = ActionResponse(state: state)
        printJSON(response)
    } else {
        printError(error ?? "failed to stop VM", exitCode: 1)
    }
}

func cmdSuspend(name: String) {
    let (success, state, error) = vmManager.suspendVM(vmName: name)
    if success {
        let response = ActionResponse(state: state)
        printJSON(response)
    } else {
        printError(error ?? "suspend not supported", exitCode: 1)
    }
}

func cmdResume(name: String) {
    let (success, state, error) = vmManager.resumeVM(vmName: name)
    if success {
        let response = ActionResponse(state: state)
        printJSON(response)
    } else {
        printError(error ?? "resume not supported", exitCode: 1)
    }
}

func cmdStatus(name: String) {
    let (state, detail) = vmManager.statusVM(vmName: name)
    let response = StatusResponse(state: state, detail: detail)
    printJSON(response)
}

// MARK: - Main

func main() {
    let args = CommandLine.arguments
    guard args.count > 1 else {
        printError("usage: applevm-helper <command> [options]\ncommands: version, list, start, stop, suspend, resume, status", exitCode: 2)
    }

    let command = args[1]

    switch command {
    case "version":
        cmdVersion()

    case "list":
        var root = ""
        var i = 2
        while i < args.count {
            if args[i] == "--root" && i + 1 < args.count {
                root = args[i + 1]
                i += 2
            } else {
                i += 1
            }
        }
        if root.isEmpty {
            printError("--root <path> is required for list command", exitCode: 2)
        }
        cmdList(root: root)

    case "start":
        var bundle = ""
        var name = ""
        var i = 2
        while i < args.count {
            if args[i] == "--bundle" && i + 1 < args.count {
                bundle = args[i + 1]
                i += 2
            } else if args[i] == "--name" && i + 1 < args.count {
                name = args[i + 1]
                i += 2
            } else {
                i += 1
            }
        }
        if bundle.isEmpty || name.isEmpty {
            printError("--bundle <path> and --name <vm> are required for start command", exitCode: 2)
        }
        cmdStart(bundle: bundle, name: name)

    case "stop":
        var name = ""
        var grace = 20
        var i = 2
        while i < args.count {
            if args[i] == "--name" && i + 1 < args.count {
                name = args[i + 1]
                i += 2
            } else if args[i] == "--grace" && i + 1 < args.count {
                grace = Int(args[i + 1]) ?? 20
                i += 2
            } else {
                i += 1
            }
        }
        if name.isEmpty {
            printError("--name <vm> is required for stop command", exitCode: 2)
        }
        cmdStop(name: name, grace: grace)

    case "suspend":
        var name = ""
        var i = 2
        while i < args.count {
            if args[i] == "--name" && i + 1 < args.count {
                name = args[i + 1]
                i += 2
            } else {
                i += 1
            }
        }
        if name.isEmpty {
            printError("--name <vm> is required for suspend command", exitCode: 2)
        }
        cmdSuspend(name: name)

    case "resume":
        var name = ""
        var i = 2
        while i < args.count {
            if args[i] == "--name" && i + 1 < args.count {
                name = args[i + 1]
                i += 2
            } else {
                i += 1
            }
        }
        if name.isEmpty {
            printError("--name <vm> is required for resume command", exitCode: 2)
        }
        cmdResume(name: name)

    case "status":
        var name = ""
        var i = 2
        while i < args.count {
            if args[i] == "--name" && i + 1 < args.count {
                name = args[i + 1]
                i += 2
            } else {
                i += 1
            }
        }
        if name.isEmpty {
            printError("--name <vm> is required for status command", exitCode: 2)
        }
        cmdStatus(name: name)

    default:
        printError("unknown command: \(command)", exitCode: 2)
    }
}

main()
