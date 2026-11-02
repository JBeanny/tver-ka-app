<p align="center">
  <img src="docs/logo.png" width="128" height="128" alt="tver-ka app icon: a lime blob in sunglasses on a hot pink sticker">
</p>

<h1 align="center">tver-ka</h1>

<p align="center">
  <b>A playful menu bar to-do app for macOS where unfinished tasks don't disappear. They roll over to tomorrow and get louder.</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-FF4FA3?style=flat-square" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-6-C6F432?style=flat-square&labelColor=17132B" alt="Swift 6">
  <img src="https://img.shields.io/badge/SwiftUI-native-3D5AFE?style=flat-square" alt="SwiftUI">
  <img src="https://img.shields.io/badge/data-100%25%20local-FFE066?style=flat-square&labelColor=17132B" alt="100% local">
</p>

<p align="center">
  <img src="docs/screenshots/today-light.png" width="300" alt="Today view in light mode">
  &nbsp;&nbsp;
  <img src="docs/screenshots/today-dark.png" width="300" alt="Today view in dark mode">
</p>

---

## Why

Most to-do apps let yesterday's unfinished tasks quietly pile up somewhere you never look. tver-ka works differently:

> If a to-do isn't done by midnight, it **slides to the next day** and gets a 🔥 **priority** sticker, with a counter showing how many days it's been carried over (`rolled ×3`).

You can't ignore it, but you can turn it off for any single task. Those tasks stay on their day and show up as **missed**, so you decide to bring them back or let them go.

## Features

- **Auto-roll.** Unfinished to-dos move to today, jump to the top as priority, and count every skipped day, even if your Mac was asleep or the app was closed.
- **Per-task control.** Switch auto-roll off for a to-do and it becomes *missed* instead, with "bring to today" and "let it go" buttons.
- **Projects.** Keep separate lists (work, uni, personal…), each with its own color. Switch with a dropdown, or pick **all projects** to work through everything in one list.
- **The done pile.** Finished to-dos stay out of the way behind one small button, grouped by day, and each one can be undone.
- **Streaks.** The streak counts the days in a row you've finished at least one to-do.
- **Menu bar icon.** A full-color mascot that's easy to spot, with your open count. A yellow dot means priority to-dos are waiting.
- **Add from your iPhone.** Turn on iCloud sync and use the included Shortcut: "Hey Siri, add to tver-ka", the Action button, or a home screen icon. To-dos land on your Mac within seconds.
- **Light, dark, or match system.**
- **Native and private.** SwiftUI, no account, no server. Your data is a single JSON file, kept on your Mac or in your own iCloud Drive.

<p align="center">
  <img src="docs/screenshots/today-all-light.png" width="240" alt="All projects view with project tags on each row">
  <img src="docs/screenshots/projects-dropdown-light.png" width="240" alt="Project switcher dropdown">
  <img src="docs/screenshots/options-light.png" width="240" alt="Task options sheet with the auto-roll toggle">
</p>
<p align="center">
  <img src="docs/screenshots/done-light.png" width="240" alt="The done pile, grouped by day">
  <img src="docs/screenshots/projects-manage-light.png" width="240" alt="Manage projects sheet">
</p>
<p align="center">
  <img src="docs/screenshots/menubar-light.png" width="240" alt="Menu bar icon on a light menu bar, normal and with the priority dot">
  <img src="docs/screenshots/menubar-dark.png" width="240" alt="Menu bar icon on a dark menu bar, normal and with the priority dot">
</p>

## Install

### Download (easiest)

1. Grab **`tver-ka-<version>.zip`** from the [latest release](https://github.com/JBeanny/tver-ka-app/releases/latest). It's one universal build for Apple Silicon and Intel Macs, and needs macOS 14 Sonoma or later.
2. Unzip it and drag **tver-ka.app** into **Applications**.
3. Open it. The first time, macOS will say it can't verify the developer. That's expected: tver-ka is a free hobby project and isn't notarized with a paid Apple Developer account. To allow it once:
   - open **System Settings › Privacy & Security**, scroll down, and click **Open Anyway** next to tver-ka, **or**
   - run `xattr -dr com.apple.quarantine /Applications/tver-ka.app` in Terminal.

   After that it opens normally. If you'd rather not trust a prebuilt binary, build it yourself (below). It's the same code.

### Build from source

**Requirements:** macOS 14 Sonoma or later, plus Xcode 16 or later (or the matching Command Line Tools with Swift 6).

```sh
git clone https://github.com/JBeanny/tver-ka-app.git
cd tver-ka-app
Scripts/bundle.sh --install      # builds and copies tver-ka.app to /Applications
open /Applications/tver-ka.app
```

The app lives only in the menu bar (no Dock icon). Look for the pink blob in sunglasses. If you use a menu bar manager or have a notch, it may start out in the hidden section, so drag it out once.

To start it automatically, open the popover and choose **`…` › Launch at login**.

**Updating:** download the newer release and replace the app, or, if you built from source, pull and run the install again. Your to-dos are stored outside the app, so they carry over.

```sh
git pull && pkill -f TverKa; Scripts/bundle.sh --install && open /Applications/tver-ka.app
```

## iPhone & iCloud

tver-ka syncs through **your own iCloud Drive**. There's no server and no extra account, and no iPhone app to install. Adding from the phone uses Apple's **Shortcuts** app.

<p align="center"><img src="docs/screenshots/phone-setup-light.png" width="260" alt="Add from iPhone setup sheet"></p>

**Set it up (once):**
1. In the menu bar popover, open **`…` › Add from iPhone…**
2. Turn on **sync with iCloud**. Your to-dos move to `iCloud Drive › tver-ka › todos.json`, and a backup of the local copy is kept.
3. Click **add to Shortcuts**. The "Add to tver-ka" shortcut is added on your Mac and syncs to your iPhone through iCloud. (Optional: **+ list viewer** adds "My tver-ka to-dos", which shows today's list on the phone.)

**Use it on iPhone:** run **Add to tver-ka** from Siri ("Hey Siri, add to tver-ka"), the Action button, a home screen icon, or the Shortcuts widget. Type or say the to-do and it appears on your Mac within about 5 seconds.

| You type | Result |
| --- | --- |
| `buy oat milk` | to-do in the project you last used |
| `#work send invoice` | goes into the **work** project (case-insensitive) |
| `call landlord !` | marked **priority** |

**How it works:** the shortcut saves each to-do as a tiny text file in `iCloud Drive › Shortcuts › tver-ka › inbox`. The Mac app checks that folder every few seconds, adds what it finds, and deletes the files. It also keeps `iCloud Drive › Shortcuts › tver-ka › Today.md` up to date, so you can read your list in the Files app or with the list-viewer shortcut.

<details>
<summary><b>Build the shortcut by hand instead</b> (if the import doesn't work)</summary>

In the Shortcuts app on iPhone, tap **+** and add:

1. **Ask for Input** → type *Text*, prompt `what's the move?`
2. **Save File** → input *Provided Input*, turn **Ask Where to Save** off, and set the destination path to `tver-ka/inbox/` + the **Current Date** variable (custom format `yyyyMMdd-HHmmss-SSS`) + `.txt`

Name it **Add to tver-ka**.
</details>

> **Good to know:** iCloud Drive sync is "last write wins". If two Macs edit at the exact same moment, one edit can be lost; iCloud keeps a conflict copy next to the file. For a single Mac plus an iPhone this doesn't come up.
>
> A full native iPhone app with live two-way sync (CloudKit) is possible later, but it needs a paid Apple Developer account.

## How rollover works

| To-do state at midnight | Auto-roll **on** (default) | Auto-roll **off** |
| --- | --- | --- |
| Not done | Moves to today, becomes priority, `rollCount += days skipped` | Stays on its day and shows as **missed** |
| Done | Stays in the done pile | Stays in the done pile |

Rollover runs on launch, when you open the popover, at the calendar day change, after the Mac wakes, and once a minute as a safety net. The rules are a pure function (`Rollover.apply`) and are covered by unit tests, including midnight boundaries and multi-day gaps.

## Your data

Everything is stored in:

```
~/Library/Application Support/tver-ka/todos.json
```

It's plain, readable JSON, so you can back it up or inspect it. With iCloud sync on, it lives in `iCloud Drive/tver-ka/todos.json` instead. Nothing ever goes anywhere but your Mac and your own iCloud.

## Development

```sh
swift build           # compile
swift test            # run the core test suite
Scripts/bundle.sh     # build build/tver-ka.app without installing
Scripts/release.sh    # universal build + build/tver-ka-<VERSION>.zip for a GitHub release
```

The version number lives in [`VERSION`](VERSION).

Debug settings (set them as environment variables and run the binary directly):

| Variable | Effect |
| --- | --- |
| `TVERKA_DAY_OFFSET=1` | Pretend it's tomorrow, to watch rollover happen |
| `TVERKA_DATA_FILE=/tmp/test.json` | Use a scratch data file instead of your real one |
| `TVERKA_ICLOUD_ROOT=/tmp/fake-icloud` | Use a fake `~/Library/Mobile Documents` (create `com~apple~CloudDocs` inside it) so sync testing never touches real iCloud. It also uses separate settings. |
| `TVERKA_SNAPSHOT_DIR=/tmp/shots` | Render every screen (light and dark) plus the menu bar icon to PNGs, then quit |

```sh
TVERKA_DAY_OFFSET=1 TVERKA_DATA_FILE=/tmp/test.json build/tver-ka.app/Contents/MacOS/TverKa
```

The app icon is drawn in code. After changing it, regenerate `Resources/AppIcon.icns` with:

```sh
swift Scripts/make-icons.swift
```

The iPhone Shortcuts are generated too, and signed with `shortcuts sign` (needs iCloud):

```sh
swift Scripts/make-shortcuts.swift   # → Shortcuts/*.shortcut
```

### Project layout

```
Sources/
  TverKaCore/          # UI-free logic, fully unit-tested
    Todo.swift         #   to-do model and status (today / priority / missed / done)
    Rollover.swift     #   the rollover rules, streak, and done-pile grouping
    Project.swift      #   projects and the on-disk file format
    TodoStore.swift    #   observable store, project scoping, JSON persistence, external-change reload
    SyncLocation.swift #   iCloud Drive paths and moving data in and out of iCloud
    InboxImporter.swift#   parses and imports to-dos dropped in by the iPhone Shortcut
    TodayDigest.swift  #   the Today.md summary for the phone
  TverKa/              # the SwiftUI menu bar app
    TverKaApp.swift    #   MenuBarExtra, day-change / wake / sync watcher
    SyncController.swift # the iCloud sync setting and inbox polling
    Views/             #   Today, done pile, task options, projects, theme, icons
Tests/TverKaCoreTests/ # Swift Testing suites
Scripts/
  bundle.sh            # build and wrap into a .app (--install, --universal)
  release.sh           # universal build, zipped for GitHub Releases
  make-icons.swift     # draws the app icon and writes AppIcon.icns
  make-shortcuts.swift # generates and signs the iPhone Shortcuts
Shortcuts/             # signed "Add to tver-ka" and "My tver-ka to-dos"
Resources/AppIcon.icns
```

## Contributing

Issues and pull requests are welcome. Please run `swift test` before opening a PR, and keep the core logic in `TverKaCore` so it stays testable.
