import Foundation
import Combine

struct TextReplacement: Identifiable {
    let id = UUID()
    let shortcut: String
    let expansion: String
}

private let appleDefaults: Set<String> = [
    "...", "(c)", "(p)", "(r)",
    "1/2", "1/3", "1/4", "1/5", "1/6", "1/8",
    "2/3", "2/5",
    "3/4", "3/5", "3/8",
    "4/5",
    "5/6", "5/8",
    "7/8",
    "omw", "TM", "c/o"
]

class TextReplacementStore: ObservableObject {
    @Published var replacements: [TextReplacement] = []

    func load() {
        if let items = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)?["NSUserDictionaryReplacementItems"] as? [[String: Any]], !items.isEmpty {
            replacements = parse(items)
            return
        }

        let prefsURL = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/.GlobalPreferences.plist")

        guard
            let data = try? Data(contentsOf: prefsURL),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
            let dict = plist as? [String: Any],
            let items = dict["NSUserDictionaryReplacementItems"] as? [[String: Any]]
        else {
            replacements = []
            return
        }

        replacements = parse(items)
    }

    private func parse(_ items: [[String: Any]]) -> [TextReplacement] {
        items.compactMap { item in
            guard
                let shortcut = item["replace"] as? String,
                let expansion = item["with"] as? String,
                !appleDefaults.contains(shortcut),
                shortcut != expansion
            else { return nil }
            return TextReplacement(shortcut: shortcut, expansion: expansion)
        }
        .sorted { $0.shortcut.lowercased() < $1.shortcut.lowercased() }
    }
}
