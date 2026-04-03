# TextPeek

A lightweight macOS menu bar app for browsing and copying your text snippets — the ones you've set up in **System Settings → Keyboard → Text Replacements**.

![macOS](https://img.shields.io/badge/macOS-26%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5-orange)

## What it does

TextPeek sits in your menu bar and gives you instant access to all your text replacements. Search, browse, and click any snippet to copy it to your clipboard.

- Browse all your macOS text replacements in one place
- Search across snippets instantly
- Click to copy any expansion
- Resizable panel

## Optional: Clipboard Manager

TextPeek also includes a clipboard history manager that runs quietly in the background and keeps a searchable log of everything you've copied (last 7 days). This is **off by default** and can be enabled in Settings.

When enabled:
- Tracks clipboard history across all apps
- Lets you exclude specific apps (e.g. password managers)
- History is stored locally at `~/Clipboard/`

## Requirements

- macOS 26 or later
- Your text replacements are set up in **System Settings → Keyboard → Text Replacements**

## Installation

Download the latest `.zip` from [Releases](../../releases), unzip, and drag `TextPeek.app` to your Applications folder.

On first launch, macOS may show a security prompt — right-click the app and choose **Open** to bypass it.

## Building from source

1. Clone the repo
2. Open `TextPeek.xcodeproj` in Xcode
3. Set your own Development Team in the project settings
4. Build and run

## Privacy

TextPeek reads your text replacements directly from macOS system preferences. No data leaves your machine. Clipboard history (if enabled) is stored only at `~/Clipboard/` on your local disk.
