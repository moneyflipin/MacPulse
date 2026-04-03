import Foundation

struct DiskUsageReader {
    func read() -> DiskStats? {
        let candidatePaths = [NSHomeDirectory(), "/"]

        do {
            for path in candidatePaths where !path.isEmpty {
                let fileSystem = try FileManager.default.attributesOfFileSystem(forPath: path)
                let total = fileSystem[.systemSize] as? UInt64 ?? 0
                let free = fileSystem[.systemFreeSize] as? UInt64 ?? 0
                let used = total > free ? total - free : 0

                if total > 0 {
                    return DiskStats(
                        usedBytes: used,
                        freeBytes: free,
                        totalBytes: total
                    )
                }
            }

            return nil
        } catch {
            return nil
        }
    }
}
