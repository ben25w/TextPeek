import SwiftUI
import ServiceManagement

enum AppTab { case replacements, clipboard, settings }

struct ResizeHandle: View {
    @Binding var height: CGFloat
    let minHeight: CGFloat = 200
    let maxHeight: CGFloat = 700

    var body: some View {
        HStack {
            Spacer()
            Image(systemName: "minus")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.quaternary)
            Spacer()
        }
        .frame(height: 14)
        .background(Color(NSColor.windowBackgroundColor))
        .gesture(
            DragGesture()
                .onChanged { value in
                    let newHeight = height + value.translation.height
                    height = min(max(newHeight, minHeight), maxHeight)
                    UserDefaults.standard.set(height, forKey: "textpeek.windowHeight")
                }
        )
        .onHover { inside in
            if inside {
                NSCursor.resizeUpDown.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

struct ContentView: View {
    @StateObject private var store     = TextReplacementStore()
    @StateObject private var clipboard = ClipboardManager()

    @State private var searchText  = ""
    @State private var listHeight: CGFloat = UserDefaults.standard.object(forKey: "textpeek.windowHeight") as? CGFloat ?? 420
    @State private var activeTab: AppTab = .replacements
    @State private var copiedID: UUID?   = nil
    @State private var launchAtLogin     = false
    @State private var newExcludedApp    = ""

    var matchingReplacements: [TextReplacement] {
        guard !searchText.isEmpty else { return store.replacements }
        return store.replacements.filter {
            $0.shortcut.localizedCaseInsensitiveContains(searchText) ||
            $0.expansion.localizedCaseInsensitiveContains(searchText)
        }
    }

    var matchingClipboard: [ClipboardItem] {
        clipboard.search(searchText)
    }

    var isSearching: Bool { !searchText.isEmpty }

    var body: some View {
        VStack(spacing: 0) {

            // ── Header ──────────────────────────────────────────
            HStack {
                HStack(spacing: 7) {
                    Image("MenuBarIcon")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 15, height: 15)
                        .foregroundStyle(.primary)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("TextPeek")
                            .font(.system(size: 14, weight: .bold))
                        Text(clipboard.isEnabled ? "\(store.replacements.count) snippets · \(clipboard.items.count) clips" : "\(store.replacements.count) snippets")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                Button {
                    store.load()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Refresh snippets")
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // ── Universal search ─────────────────────────────────
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.tertiary)
                    .font(.system(size: 11))
                TextField("Search snippets and clipboard...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color(NSColor.controlBackgroundColor)))
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            // ── Tabs ─────────────────────────────────────────────
            if !isSearching {
                HStack(spacing: 4) {
                    TabButton(label: "Snippets", count: store.replacements.count, active: activeTab == .replacements) {
                        activeTab = .replacements
                    }
                    if clipboard.isEnabled {
                        TabButton(label: "Clipboard", count: clipboard.recentItems.count, active: activeTab == .clipboard) {
                            activeTab = .clipboard
                        }
                    }
                    TabButton(label: "Settings", count: nil, active: activeTab == .settings) {
                        activeTab = .settings
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
            }

            Divider()

            // ── Content ──────────────────────────────────────────
            ScrollView {
                LazyVStack(spacing: 0) {

                    if isSearching {
                        if matchingReplacements.isEmpty && matchingClipboard.isEmpty {
                            EmptyState(message: "Nothing matched \"\(searchText)\"")
                        }
                        if !matchingReplacements.isEmpty {
                            SectionHeader(title: "Snippets", count: matchingReplacements.count)
                            ForEach(matchingReplacements) { item in
                                ReplacementRow(item: item, copiedID: $copiedID)
                                Divider().padding(.leading, 14)
                            }
                        }
                        if !matchingClipboard.isEmpty {
                            SectionHeader(title: "Clipboard", count: matchingClipboard.count)
                            ForEach(matchingClipboard) { item in
                                ClipboardRow(item: item, copiedID: $copiedID,
                                    onDelete: { clipboard.deleteItem(item) },
                                    onCopy:   { clipboard.copyItem(item) })
                                Divider().padding(.leading, 14)
                            }
                        }

                    } else if activeTab == .replacements {
                        if store.replacements.isEmpty {
                            EmptyState(message: "No snippets found")
                        } else {
                            ForEach(store.replacements) { item in
                                ReplacementRow(item: item, copiedID: $copiedID)
                                Divider().padding(.leading, 14)
                            }
                        }

                    } else if activeTab == .clipboard {
                        if clipboard.recentItems.isEmpty {
                            EmptyState(message: "Nothing copied yet")
                        } else {
                            HStack {
                                Text("Showing last 20 — search to see more")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.quaternary)
                                Spacer()
                                Menu("Clear...") {
                                    Button("Clear last hour") {
                                        clipboard.clearOlderThan(hours: 1)
                                    }
                                    Button("Clear last day") {
                                        clipboard.clearOlderThan(hours: 24)
                                    }
                                    Divider()
                                    Button("Clear all", role: .destructive) {
                                        clipboard.clearAll()
                                    }
                                }
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .menuStyle(.borderlessButton)
                                .fixedSize()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            ForEach(clipboard.recentItems) { item in
                                ClipboardRow(item: item, copiedID: $copiedID,
                                    onDelete: { clipboard.deleteItem(item) },
                                    onCopy:   { clipboard.copyItem(item) })
                                Divider().padding(.leading, 14)
                            }
                        }

                    } else if activeTab == .settings {
                        SettingsView(
                            clipboard: clipboard,
                            newExcludedApp: $newExcludedApp,
                            launchAtLogin: $launchAtLogin
                        )
                    }
                }
            }
            .frame(height: listHeight)

            ResizeHandle(height: $listHeight)

            Divider()

            // ── Footer ───────────────────────────────────────────
            HStack {
                Button {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 10))
                        Text("Edit Snippets")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 7)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color(NSColor.controlBackgroundColor)))
                }
                .buttonStyle(.plain)
                Spacer()
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "power")
                            .font(.system(size: 10))
                        Text("Quit")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 7)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color(NSColor.controlBackgroundColor)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
        }
        .frame(width: 320)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            store.load()
            launchAtLogin = getLaunchAtLoginState()
        }
        .onChange(of: clipboard.isEnabled) {
            if !clipboard.isEnabled && activeTab == .clipboard {
                activeTab = .replacements
            }
        }
    }

    func getLaunchAtLoginState() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }
}

// MARK: - Subviews

struct TabButton: View {
    let label: String
    let count: Int?
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 11, weight: active ? .semibold : .regular))
                if let count {
                    Text("\(count)")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color(NSColor.controlBackgroundColor)))
                }
            }
            .foregroundStyle(active ? .primary : .secondary)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(active ? Color(NSColor.selectedControlColor).opacity(0.15) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

struct SectionHeader: View {
    let title: String
    let count: Int
    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
                .kerning(0.5)
            Text("\(count)")
                .font(.system(size: 9))
                .foregroundStyle(.quaternary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

struct EmptyState: View {
    let message: String
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "tray")
                .font(.system(size: 20))
                .foregroundStyle(.tertiary)
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

struct ReplacementRow: View {
    let item: TextReplacement
    @Binding var copiedID: UUID?
    var isCopied: Bool { copiedID == item.id }

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(item.expansion, forType: .string)
            withAnimation(.easeInOut(duration: 0.15)) { copiedID = item.id }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                withAnimation { if copiedID == item.id { copiedID = nil } }
            }
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.shortcut)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(RoundedRectangle(cornerRadius: 3).fill(Color(NSColor.controlBackgroundColor)))
                    Text(item.expansion)
                        .font(.system(size: 12))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                CopiedBadge(isCopied: isCopied)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .background(isCopied ? Color.green.opacity(0.06) : Color.clear)
        }
        .buttonStyle(.plain)
    }
}

struct ClipboardRow: View {
    let item: ClipboardItem
    @Binding var copiedID: UUID?
    let onDelete: () -> Void
    let onCopy: () -> Void
    var isCopied: Bool { copiedID == item.id }

    var body: some View {
        Button {
            onCopy()
            withAnimation(.easeInOut(duration: 0.15)) { copiedID = item.id }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                withAnimation { if copiedID == item.id { copiedID = nil } }
            }
        } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.text)
                        .font(.system(size: 12))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 6) {
                        if let app = item.appName {
                            Text(app)
                                .font(.system(size: 9))
                                .foregroundStyle(.quaternary)
                        }
                        Text(item.date.formatted(.relative(presentation: .named)))
                            .font(.system(size: 9))
                            .foregroundStyle(.quaternary)
                    }
                }
                Spacer()
                VStack(spacing: 6) {
                    CopiedBadge(isCopied: isCopied)
                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 9))
                            .foregroundStyle(.quaternary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .background(isCopied ? Color.green.opacity(0.06) : Color.clear)
        }
        .buttonStyle(.plain)
    }
}

struct CopiedBadge: View {
    let isCopied: Bool
    var body: some View {
        if isCopied {
            HStack(spacing: 3) {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                Text("Copied")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(.green)
            .transition(.opacity.combined(with: .scale(scale: 0.85)))
        } else {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 11))
                .foregroundStyle(.quaternary)
                .transition(.opacity)
        }
    }
}

struct SettingsView: View {
    @ObservedObject var clipboard: ClipboardManager
    @Binding var newExcludedApp: String
    @Binding var launchAtLogin: Bool

    @State private var updateState: UpdateState = .idle

    enum UpdateState {
        case idle, checking, upToDate, available(String), failed
    }

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Clipboard manager")
                        .font(.system(size: 12))
                    Text("Track clipboard history in the background")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: $clipboard.isEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Launch at login")
                        .font(.system(size: 12))
                    Text("Start TextPeek automatically when you log in")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: $launchAtLogin)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .onChange(of: launchAtLogin) {
                        if #available(macOS 13.0, *) {
                            try? launchAtLogin
                                ? SMAppService.mainApp.register()
                                : SMAppService.mainApp.unregister()
                        }
                    }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Excluded apps")
                        .font(.system(size: 12, weight: .medium))
                    Text("Clipboard items from these apps are ignored")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    TextField("App name e.g. 1Password", text: $newExcludedApp)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Color(NSColor.controlBackgroundColor)))
                        .onSubmit { addExcluded() }
                    Button("Add") { addExcluded() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Color(NSColor.controlBackgroundColor)))
                }
                if clipboard.excludedApps.isEmpty {
                    Text("No apps excluded yet")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(clipboard.excludedApps, id: \.self) { app in
                        HStack {
                            Text(app).font(.system(size: 11))
                            Spacer()
                            Button {
                                clipboard.removeExcludedApp(app)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Color(NSColor.controlBackgroundColor)))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Storage")
                    .font(.system(size: 12, weight: .medium))
                Text("History saved to ~/Clipboard/")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Button("Open in Finder") {
                    NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Clipboard"))
                }
                .buttonStyle(.plain)
                .font(.system(size: 10))
                .foregroundStyle(.blue)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Updates")
                        .font(.system(size: 12, weight: .medium))
                    Text("v\(currentVersion)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Group {
                    switch updateState {
                    case .idle:
                        Button("Check") { checkForUpdates() }
                    case .checking:
                        Text("Checking…")
                            .foregroundStyle(.secondary)
                    case .upToDate:
                        Text("Up to date")
                            .foregroundStyle(.secondary)
                    case .available(let version):
                        Button("v\(version) available") {
                            NSWorkspace.shared.open(URL(string: "https://github.com/ben25w/TextPeek/releases/latest")!)
                        }
                        .foregroundStyle(.blue)
                    case .failed:
                        Text("Check failed")
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }

    func checkForUpdates() {
        updateState = .checking
        let url = URL(string: "https://api.github.com/repos/ben25w/TextPeek/releases/latest")!
        URLSession.shared.dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async {
                guard
                    let data,
                    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let tag = json["tag_name"] as? String
                else {
                    updateState = .failed
                    return
                }
                let latest = tag.trimmingCharacters(in: .init(charactersIn: "v"))
                updateState = latest.compare(currentVersion, options: .numeric) == .orderedDescending
                    ? .available(latest)
                    : .upToDate
            }
        }.resume()
    }

    func addExcluded() {
        clipboard.addExcludedApp(newExcludedApp)
        newExcludedApp = ""
    }
}
