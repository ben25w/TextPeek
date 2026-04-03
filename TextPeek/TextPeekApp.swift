import SwiftUI

@main
struct TextPeekApp: App {
    var body: some Scene {
        MenuBarExtra("TextPeek", systemImage: "text.alignleft") {
            ContentView()
        }
        .menuBarExtraStyle(.window)
    }
}
