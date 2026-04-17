# Localhost 3000 — Agent Instructions

## What this is

A native macOS app (Swift 6, SwiftUI, macOS 14+) that scans a portfolio folder for npm projects and lets you start/stop their dev servers, see git status, edit ports, and open each project in the browser, terminal, VS Code, or Finder.

No Xcode. Built entirely with Swift Package Manager.

## Rules for agents

After every code change — bug fix, feature, tweak, anything — always:
1. Run `./build-app.sh` to rebuild the app
2. Kill the running instance and relaunch: `pkill -f "Localhost 3000"; sleep 0.5; open "dist/Localhost 3000.app"`
3. Commit and push the change to GitHub
4. Upload the zip to the GitHub release: `gh release upload v0.1.0 dist/localhost-3000-macos.zip --clobber --repo serdarsalim/localhost-3000`

Do not ask the user if they want this done. Just do it every time.

## Build & run

```bash
swift build -c release      # compile
./build-app.sh              # bundle + sign → dist/Localhost 3000.app
open "dist/Localhost 3000.app"
```

To rebuild and relaunch in one shot:
```bash
./build-app.sh && pkill -f "Localhost 3000"; sleep 0.5; open "dist/Localhost 3000.app"
```

## Project structure

```
Package.swift                        SPM config, Swift 6, macOS 14+
build-app.sh                         builds .app bundle, generates icon, ad-hoc signs, zips
AppIcon.png                          source icon (1024×1024), converted to .icns by build script
make-icon.swift                      generates AppIcon.png from SF Symbol globe

Sources/LocalhostApp/
  App.swift                          @main entry + AppDelegate
  Models.swift                       DevApp, GitStatus (Sendable structs)
  PortStore.swift                    load/save ports in UserDefaults (key: "appPorts")
  AppScanner.swift                   scans portfolio root for dirs with package.json + "dev" script
  ProcessManager.swift               @MainActor, starts/stops npm via /bin/zsh exec npm run dev
  GitClient.swift                    async git status checks via Task.detached shell calls
  SystemClient.swift                 open Terminal / VS Code / Finder / browser, copy LAN URL
  AppModel.swift                     @MainActor ObservableObject — all app logic
  ContentView.swift                  welcome screen + dashboard layout + footer
  AppRowView.swift                   per-app row: status dot, name, port editor, git badge, actions
  HelpView.swift                     in-app help sheet (opened from footer Help button)
  ScrollWheelModifier.swift          NSViewRepresentable scroll wheel capture for port nudging
  NativeTextField.swift              NSViewRepresentable text field (currently unused — kept for reference)
```

## Key decisions & gotchas

**Port persistence** — `PortStore` uses `UserDefaults`. Critical: `defaults.dictionary(forKey:)` returns `[String: Any]`, which cannot be cast directly to `[String: Int]`. Always use `compactMapValues { $0 as? Int }` to extract values. This was a root-cause bug — don't revert it.

**Process spawning** — uses `/bin/zsh -c "exec npm run dev"` with PATH set to include `/opt/homebrew/bin:/usr/local/bin`. The `exec` replaces the shell so `process.terminate()` hits npm directly.

**Port environment** — sets both `PORT` and `VITE_PORT` env vars. Next.js reads `PORT`, Vite projects may need `--port` in their dev script instead.

**Terminal button** — uses `open -a Terminal <path>`, NOT AppleScript. AppleScript requires special entitlements the ad-hoc signed app doesn't have.

**Dark/light mode** — stored in `@AppStorage("colorScheme")` as `"light"` or `"dark"`. Toggle in footer cycles between the two.

**Port editing UX** — clicking port number opens inline editor with ↑↓ arrows (left), text field, scroll wheel nudge, ✓ save, ✗ cancel. Enter also saves. `savePort()` calls `model.updatePort(for:port:)` directly.

**Signing** — ad-hoc only (`codesign --sign -`). No Apple Developer account needed. Users get a Gatekeeper warning on first launch; right-click → Open bypasses it.

**No Xcode project** — never add one. SPM only.

**No third-party dependencies** — keep it that way.

## State flow

```
AppModel (@MainActor ObservableObject)
  ├── refresh() — scans folder, assigns ports, fetches git status in parallel
  ├── start(app:) — ProcessManager.start → updates apps[].isRunning
  ├── stop(app:) — ProcessManager.stop → updates apps[].isRunning
  └── updatePort(for:port:) — PortStore.save + updates apps[].port in memory

PortStore — UserDefaults key "appPorts" ([String: Int])
ProcessManager — @MainActor, tracks [String: Process]
GitClient — static async, runs git via Task.detached
SystemClient — static, AppKit calls (open, NSWorkspace, NSPasteboard)
```

## GitHub

Repo: https://github.com/serdarsalim/localhost-3000
Push after changes: `git add -A && git commit -m "..." && git push`
