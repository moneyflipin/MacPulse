import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
enum SystemActionCenter {
    static func openActivityMonitor() {
        let url = URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    @discardableResult
    static func activate(process: ProcessResource) -> Bool {
        guard let application = NSRunningApplication(processIdentifier: pid_t(process.pid)) else {
            return false
        }
        return application.activate()
    }

    @discardableResult
    static func terminate(process: ProcessResource) -> Bool {
        guard let application = NSRunningApplication(processIdentifier: pid_t(process.pid)) else {
            return false
        }
        return application.terminate()
    }

    @discardableResult
    static func reveal(process: ProcessResource) -> Bool {
        guard let executablePath = process.executablePath else {
            return false
        }

        let url = URL(fileURLWithPath: executablePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return false
        }

        NSWorkspace.shared.activateFileViewerSelecting([url])
        return true
    }

    @discardableResult
    static func exportReport(_ content: String, format: ReportExportFormat) -> Bool {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [contentType(for: format)]
        panel.nameFieldStringValue = "Отчет MacPulse \(Date.now.formatted(date: .numeric, time: .omitted)).\(format.fileExtension)"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else {
            return false
        }

        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }

    private static func contentType(for format: ReportExportFormat) -> UTType {
        switch format {
        case .plainText:
            .plainText
        case .markdown:
            UTType(filenameExtension: "md") ?? .plainText
        }
    }
}
