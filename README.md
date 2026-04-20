[English](./README.md) | [한국어](./README_KO.md)

# TodoMenu

A lightweight macOS menu bar app for daily markdown todos.

![TodoMenu](./screenshot.png)

## Features

- Lives in the menu bar, no Dock icon
- Auto-creates a daily `YYYY-MM-DD TODO.md` file in your notes directory
- Organizes todos into four sections: `ROUTINE`, `SLIT`, `SPEC`, `OTHERS`
- Toggle checkboxes directly from the menu bar
- Quick-add todos without opening any editor
- Optional scaffold template for consistent daily file structure
- Opens files in Obsidian via URL scheme
- Watches for file changes and refreshes automatically
- Detects day rollover at midnight and switches to the new day's file

## Requirements

- macOS 14 or later
- Swift 6.0 or later

## Build & Install

```sh
swift build
swift test
```

```sh
./Scripts/package_app.sh
cp -R TodoMenu.app ~/Applications/
open ~/Applications/TodoMenu.app
```

To launch at login, go to System Settings → General → Login Items and add TodoMenu.

## Usage

On first launch, open the menu bar icon and configure:

- **Notes directory** — where your daily `YYYY-MM-DD TODO.md` files live
- **Scaffold template** (optional) — a markdown template copied into each new daily file

Config is stored at `~/Library/Application Support/TodoMenu/config.json`.

## Project Structure

```
Sources/
  TodoDomain/       Core parsing and mutation logic
  TodoMenuApp/      SwiftUI app, UI, config, lifecycle
Tests/              Unit tests
Scripts/            Build and packaging scripts
```

## License

MIT
