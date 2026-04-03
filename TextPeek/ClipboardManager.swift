import Foundation
import AppKit
import Combine

struct ClipboardItem: Identifiable, Codable {
    let id: UUID
    let text: String
    let date: Date
    let appName: String?

    init(text: String, appName: String?) {
        self.id = UUID()
        self.text = text
        self.date = Date()
        self.appName = appName
    }
}

class ClipboardManager: ObservableObject {
    @Published var items: [ClipboardItem] = []
    @Published var excludedApps: [String] = []
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "textpeek.clipboardEnabled")
            isEnabled ? startMonitoring() : stopMonitoring()
        }
    }

    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private let storageDir: URL
    private let historyFile: URL
    private let excludedFile: URL
    private let maxAgeDays: Double = 7
    private let displayLimit = 20

    init() {
        isEnabled = UserDefaults.standard.object(forKey: "textpeek.clipboardEnabled") as? Bool ?? true
        storageDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Clipboard")
        historyFile = storageDir.appendingPathComponent("history.json")
        excludedFile = storageDir.appendingPathComponent("excluded.json")
        createStorageDir()
        loadHistory()
        loadExcluded()
        pruneOldItems()
        if isEnabled { startMonitoring() }
    }

    // MARK: - Setup

    private func createStorageDir() {
        try? FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
    }

    func startMonitoring() {
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Clipboard checking

    private func checkClipboard() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        guard let text = pb.string(forType: .string), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // Check excluded apps
        let frontApp = NSWorkspace.shared.frontmostApplication?.localizedName ?? ""
        if excludedApps.contains(where: { frontApp.localizedCaseInsensitiveContains($0) }) { return }

        // Don't duplicate the most recent item
        if let last = items.first, last.text == text { return }

        let item = ClipboardItem(text: text, appName: frontApp.isEmpty ? nil : frontApp)
        DispatchQueue.main.async {
            self.items.insert(item, at: 0)
            self.saveHistory()
        }
    }

    // MARK: - Display

    var recentItems: [ClipboardItem] {
        Array(items.prefix(displayLimit))
    }

    func search(_ query: String) -> [ClipboardItem] {
        guard !query.isEmpty else { return recentItems }
        return items.filter { $0.text.localizedCaseInsensitiveContains(query) }
    }

    // MARK: - Actions

    func copyItem(_ item: ClipboardItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.text, forType: .string)
        lastChangeCount = NSPasteboard.general.changeCount
    }

    func deleteItem(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        saveHistory()
    }

    func clearOlderThan(hours: Int) {
        let cutoff = Date().addingTimeInterval(-Double(hours) * 3600)
        items.removeAll { $0.date < cutoff }
        saveHistory()
    }

    func clearAll() {
        items.removeAll()
        saveHistory()
    }

    // MARK: - Excluded apps

    func addExcludedApp(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !excludedApps.contains(trimmed) else { return }
        excludedApps.append(trimmed)
        saveExcluded()
    }

    func removeExcludedApp(_ name: String) {
        excludedApps.removeAll { $0 == name }
        saveExcluded()
    }

    // MARK: - Persistence

    private func pruneOldItems() {
        let cutoff = Date().addingTimeInterval(-maxAgeDays * 86400)
        items = items.filter { $0.date > cutoff }
        saveHistory()
    }

    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: historyFile)
    }

    private func loadHistory() {
        guard
            let data = try? Data(contentsOf: historyFile),
            let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data)
        else { return }
        items = decoded
    }

    private func saveExcluded() {
        guard let data = try? JSONEncoder().encode(excludedApps) else { return }
        try? data.write(to: excludedFile)
    }

    private func loadExcluded() {
        guard
            let data = try? Data(contentsOf: excludedFile),
            let decoded = try? JSONDecoder().decode([String].self, from: data)
        else { return }
        excludedApps = decoded
    }
}
