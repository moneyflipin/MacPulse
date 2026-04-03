import Foundation

struct ProcessListReader {
    func read(limit: Int = 5) -> ProcessSummary? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,%cpu=,rss=,comm="]
        process.qualityOfService = .utility

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        let completion = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in
            completion.signal()
        }

        do {
            try process.run()
        } catch {
            return nil
        }

        let timeout = completion.wait(timeout: .now() + 1.5)
        if timeout == .timedOut {
            if process.isRunning {
                process.interrupt()
            }
            if process.isRunning {
                process.terminate()
            }
            return nil
        }

        guard process.terminationStatus == 0 else {
            return nil
        }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            return nil
        }

        let allProcesses = output
            .split(whereSeparator: \.isNewline)
            .compactMap(parse(line:))
            .filter { $0.pid != ProcessInfo.processInfo.processIdentifier }

        let topCPU = allProcesses
            .filter { $0.cpuPercent > 0.1 }
            .sorted { lhs, rhs in
                if lhs.cpuPercent == rhs.cpuPercent {
                    return lhs.memoryBytes > rhs.memoryBytes
                }
                return lhs.cpuPercent > rhs.cpuPercent
            }

        let topMemory = allProcesses
            .filter { $0.memoryBytes > 0 }
            .sorted { lhs, rhs in
                if lhs.memoryBytes == rhs.memoryBytes {
                    return lhs.cpuPercent > rhs.cpuPercent
                }
                return lhs.memoryBytes > rhs.memoryBytes
            }

        return ProcessSummary(
            topCPU: Array(topCPU.prefix(limit)),
            topMemory: Array(topMemory.prefix(limit))
        )
    }

    private func parse(line: Substring) -> ProcessResource? {
        let components = line.split(maxSplits: 3, omittingEmptySubsequences: true) { $0 == " " || $0 == "\t" }
        guard components.count == 4 else { return nil }

        let pidString = String(components[0])
        let cpuString = String(components[1]).replacingOccurrences(of: ",", with: ".")
        let rssString = String(components[2])
        let rawCommand = String(components[3])
        let name = friendlyName(from: rawCommand)

        guard
            let pid = Int(pidString),
            let cpuPercent = Double(cpuString),
            let rssKilobytes = UInt64(rssString)
        else {
            return nil
        }

        return ProcessResource(
            pid: pid,
            name: name,
            cpuPercent: cpuPercent,
            memoryBytes: rssKilobytes * 1024,
            executablePath: rawCommand.hasPrefix("/") ? rawCommand : nil
        )
    }

    private func friendlyName(from command: String) -> String {
        if command.hasPrefix("/") {
            let url = URL(fileURLWithPath: command)
            let lastComponent = url.deletingPathExtension().lastPathComponent
            if lastComponent.isEmpty {
                return command
            }
            return lastComponent
        }

        return command
    }
}
